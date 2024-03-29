/**
 * Created by dgajwani on 9/24/18.
 */

public with sharing class phss_cc_ProductUtil {
    private static final String PRODUCT_SFID_KEY = 'sfid';

    // Product Spec names and values
    public static final String CLASS_SPEC_NAME = 'Class';
    public static final String LEARN_TO_SWIM_PRODUCT_SPEC = 'LTS';

    private static final String FAILED_TO_PERFORM_SEARCH_REQUEST = 'Failed to perform search request.';
    private static final String FAILED_TO_GET_PRODUCT_DETAILS = 'Failed to get Product Details.';
    private static final String FAILED_TO_PERFORM_SEARCH = 'Failed to perform search.';
    private static final String FAILED_TO_PERFORM_FILTERED_PRODUCT_SEARCH = 'Failed to perform filtered product search.';
    private static final String FAILED_TO_CREATE_A_PRODUCT_MAP = 'Failed to create a product map.';
    private static final String FAILED_TO_GET_PRODUCTS_MATCHING_SPECS = 'Failed to get products matching product specs.';

    @TestVisible private static final String PRODUCT_LIST_KEY = 'productList';
    @TestVisible private static final String PRODUCT_MAP_KEY = 'productMap';

    /**
     * @description Performs a search to return all products matching the query string.
     *
     * @param query
     */
    public static Set<String> doSearch(String searchString) {
        Set<String> searchResults;
        System.debug('Search string sent'+searchString);
        try {
            Map<String, Object> request = new Map<String, Object>{
                    ccrz.ccApi.API_VERSION => ccrz.ccApi.CURRENT_VERSION,
                    ccrz.ccService.SEARCHSTRING => searchString
            };
            Map<String, Object> response = ccrz.ccAPIProduct.search(request);
            Boolean isSuccess = (Boolean) response.get(ccrz.ccAPI.SUCCESS);
            if (isSuccess) {
                searchResults = (Set<String>) response.get(ccrz.ccService.SEARCHRESULTS);
            }
        } catch (Exception e) {
            throw new phss_cc_Exception(FAILED_TO_PERFORM_SEARCH_REQUEST);
        }
        System.debug('result based on search'+searchResults);
        return searchResults;
    }

    /**
     * @description Performs a ccApiProduct.fetch on each of the product IDs to get relevant details.
     *
     * @param productSfids
     *
     * @return
     */
    public static List<Map<String, Object>> getProductDetails(Set<String> productIds) {
        List<Map<String, Object>> productDataList;
        try {
            Map<String, Object> request = new Map<String, Object>{
                    ccrz.ccApi.API_VERSION => ccrz.ccApi.CURRENT_VERSION,
                    ccrz.ccApiProduct.PARAM_INCLUDE_PRICING => true,
                    ccrz.ccAPIProduct.PRODUCTIDLIST => productIds,
                    ccrz.ccApi.SIZING => new Map<String, Object>{
                            ccrz.ccAPIProduct.ENTITYNAME => new Map<String, Object>{
                                    ccrz.ccAPI.SZ_DATA => ccrz.ccAPI.SZ_XL
                            }
                    }
            };

            Map<String, Object> response = ccrz.ccAPIProduct.fetch(request);
            Boolean isSuccess = (Boolean) response.get(ccrz.ccAPI.SUCCESS);
            if (isSuccess) {
                productDataList = (List<Map<String, Object>>) response.get(ccrz.ccAPIProduct.PRODUCTLIST);
            }
        } catch (Exception e) {
            throw new phss_cc_Exception(FAILED_TO_GET_PRODUCT_DETAILS);
        }
        return productDataList;
    }

    /**
     * @description Creates a map of SFID->ProductDetails. This is done for easy rendering in Lightning component.
     *
     * @param productData
     *
     * @return
     */
    public static Map<String, Object> getProductMapKeyedToSfidMap(List<Map<String, Object>> productData) {
        Map<String, Object> productsById;
        try {
            productsById = new Map<String, Object>();
            for (Object obj : productData) {
                Map<String, Object> currProduct = (Map<String, Object>) obj;
                String productSfid = (String) currProduct.get(PRODUCT_SFID_KEY);
                productsById.put(productSfid, currProduct);
            }
        } catch (Exception e) {
            throw new phss_cc_Exception(FAILED_TO_CREATE_A_PRODUCT_MAP);
        }
        return productsById;
    }

    /**
     * @description Returns a Map of product Details of all products matching the query string.
     *
     * @param query
     *
     * @return
     */
    public static Map<String, Object> productSearch(String opportunitySfid,String searchString) {
        Map<String, Object> searchResponse;
        List<Map<String, Object>> productData = new List<Map<String, Object>>();
        Map<String, Object> productMap = new Map<String, Object>();

        try {
            phss_cc_Context.setContext(opportunitySfid);
            Set<String> productIds = doSearch(searchString);
            if (productIds.size() > 0) {
                productData = getProductDetails(productIds);
                if (productData!=null && !productData.isEmpty()){
                    productMap = getProductMapKeyedToSfidMap(productData);
                }
            }
        } catch (Exception e) {
            throw new phss_cc_Exception(FAILED_TO_PERFORM_SEARCH);
        }
        searchResponse = new Map<String, Object>{
                PRODUCT_LIST_KEY => productMap.keySet(),
                PRODUCT_MAP_KEY => productMap
        };
        return searchResponse;
    }

    public static Map<String, Object> filteredProductSearch(String opportunityId, String searchString, Map<String, String> filterMap) {
        try {
            Map<String, Object> productInfo = productSearch(opportunityId, searchString);
            Set<String> productList = (Set<String>) productInfo.get(PRODUCT_LIST_KEY);
            Map<String, Object> productMap = (Map<String, Object>) productInfo.get(PRODUCT_MAP_KEY);

            Set<String> filteredProductIds = productsMatchingSpecs(productList, filterMap);
            Map<String, Object> products = new Map<String, Object>();
            for (String productId : filteredProductIds) {
                Object product = productMap.get(productId);
                products.put(productId, product);
            }
            productInfo = new Map<String, Object>{
                    PRODUCT_LIST_KEY => products.keySet(),
                    PRODUCT_MAP_KEY => products
            };
            return productInfo;
        } catch (Exception e) {
            throw new phss_cc_Exception(FAILED_TO_PERFORM_FILTERED_PRODUCT_SEARCH, e);
        }
    }

    public static Set<String> productsMatchingSpecs(Set<String> productIds, Map<String, String> filterMap) {
        try {
            String products = '(\'' + String.join(new List<String>(productIds), '\',\'') + '\')';

            String filter = '';
            for (String name : filterMap.keySet()) {
                String specName = String.escapeSingleQuotes(name);
                String specValue = String.escapeSingleQuotes(filterMap.get(name));
                filter += ' AND (ccrz__Spec__r.Name = \'' + specName + '\' AND ccrz__SpecValue__c = \'' + specValue + '\')';
            }

            String queryString = 'SELECT ccrz__Product__c FROM ccrz__E_ProductSpec__c WHERE ccrz__Product__c IN ' + products + filter;
            List<ccrz__E_ProductSpec__c> productSpecs = Database.query(queryString);
            Set<String> matchingProductIds = new Set<String>();
            for (ccrz__E_ProductSpec__c productSpec : productSpecs) {
                matchingProductIds.add(productSpec.ccrz__Product__c);
            }

            return matchingProductIds;
        } catch (Exception e) {
            throw new phss_cc_Exception(FAILED_TO_GET_PRODUCTS_MATCHING_SPECS, e);
        }
    }

    /**
     * @description Return a map of a map of SFID->ProductDetails. This is done for easy rendering in Lightning component.
     *
     * @param productSfids
     *
     * @return
     */
    public static Map<String, Object> getProductDetailsKeyedToSfidMap(Set<String> productIds){
        Map<String, Object> productsById;
        try {
            if (productIds.size() > 0) {
                List<Map<String, Object>> productDetails = getProductDetails(productIds);
                productsById = getProductMapKeyedToSfidMap(productDetails);
            }
        } catch (Exception e) {
            throw new phss_cc_Exception(FAILED_TO_PERFORM_SEARCH);
        }
        return productsById;
    }
}