/**
 * Controller for the ltng_UnifiedLinks page.
 * <p>To see the URL Schemes available for Lightning Experience, see:
 *    https://developer.salesforce.com/docs/atlas.en-us.lightning.meta/lightning/components_navigation_page_definitions.htm
 * </p>
 * <p>To see the URL schemes available for Salesforce1, see:
 *    https://resources.docs.salesforce.com/208/latest/en-us/sfdc/pdf/salesforce1_url_schemes.pdf
 * </p>
 * <p>Review further: https://joebuschmann.com/salesforce-lightning-navigation-events-in-a-visualforce-page/</p>
 * @class ltng_UnifiedLinksPortalCtrl
 **/
public with sharing class ltng_UnifiedLinksPortalCtrl {

    /** Permission that determines if the user has access to LEX **/
    public static final String PERM_LEX_ENABLED = 'LightningExperienceUser';

    /** default url encoding/decoding scheme **/
    public static final String DEFAULT_URL_ENCODING_SCHEME = 'UTF-8';

    /** Default page to redirect someone to **/
    public static final String DEFAULT_REDIRECTION = '/a00';
    /** Default prompt for redirection **/
    public static final String DEFAULT_REDIRECTION_PROMPT = 'We were unable to redirect you. Please contact your administrator';
    /** default redirection parameters **/
    public static final String DEFAULT_REDIRECTION_PARAMS = '{}';

    /** start of mustache template **/
    public static final String MUSTACHE_START = '{{';
    /** end of mustache template **/
    public static final String MUSTACHE_END = '}}';

    /** parameter for the redirection type **/
    public static final String PARAM_REDIRECTION_TYPE = 'redirType';
    /** parameter for the replacement info **/
    public static final String PARAM_REDIRECTION_PARAMS = 'redirParams';
    /** parameter to stop redirection **/
    public static final String PARAM_DEBUG = 'debug';

    /** The redirection prompt to show to the end user before redirecting **/
    public String redirectionPrompt {get;set;}
    /** The actual URL to redirect the user to **/
    public String redirectionURL {get;set;}
    /** whether to run in debug mode **/
    public Boolean debugMode {get;set;}

    //-- debug form inputs
    /** redirection type **/
    public String debugRedirectType {get;set;}
    /** redirection params **/
    public String debugRedirectParams {get;set;}

    public ltng_UnifiedLinksPortalCtrl(){
        Boolean redirectWithLightning = isLightningUser(null);
        String redirectionType = getRedirectionType();
        ltng_UnifiedLinkScheme__c targetScheme = findUnifiedScheme(redirectionType);
        String redirectionParamsStr = getRedirectionParameters();
        Map<String,String> redirectionParams = convertJSON_toMap(redirectionParamsStr);
        String redirectionTemplate;

        this.redirectionPrompt = DEFAULT_REDIRECTION_PROMPT;
        this.redirectionURL = DEFAULT_REDIRECTION;
        this.debugMode = shouldRunInDebugMode();

        //-- set debug info
        this.debugRedirectType = redirectionType;
        this.debugRedirectParams = redirectionParamsStr;

        if( targetScheme != null ){
            System.debug('targetScheme is not null');

            System.debug('targetScheme'); System.debug(targetScheme);
            System.debug('redirectionParams'); System.debug(redirectionParams);

            //-- for now only care about classic vs lightning
            this.redirectionPrompt = applyMustacheTemplate(
                targetScheme.RedirectionPrompt__c, redirectionParams
            );

            redirectionTemplate = targetScheme.UrlSchemeClassic__c;
            if( redirectWithLightning ){
                redirectionTemplate = targetScheme.UrlSchemeLightningExperience__c;
            }

            this.redirectionURL = applyMustacheTemplate(
                redirectionTemplate, redirectionParams
            );
        }
    }

    public PageReference redirectUser(){
        PageReference result = new PageReference(this.redirectionURL);

        if( this.debugMode ){
            result = null;
        }
        
        return( result );
    }

    /**
     * Determine if the current user should have a Lightning redirection (true)
     * or redirection to classic (false)
     * @param (Id) targetUserId - the Id of the user to query - or null for current user.
     * @return (Boolean) - whether to redirect to a lightning version (true) or classic (false)
     */
    public Boolean isLightningUser( Id targetUserId ){
        if( targetUserId == null ){
            targetUserId = UserInfo.getUserId();
        }

        User currentUser = [ SELECT Id, UserPreferencesLightningExperiencePreferred
            FROM User
            WHERE Id = :targetUserId
            LIMIT 1
        ];

        //-- see here for more on the field on user
        //-- https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_user.htm#UserPreferencesLightningExperiencePreferred
        Boolean results = currentUser.UserPreferencesLightningExperiencePreferred == TRUE;

        //-- @TODO: investigate whether we need to use the PermissionApproach
        //-- see here for more on checkPermission
        //-- https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_class_System_FeatureManagement.htm
        //-- The permission is the API Name of the 'Lightning Experience' custom permission.
        results = results || System.FeatureManagement.checkPermission( PERM_LEX_ENABLED );

        return( results );
    }

    /**
     * Determine the type of redirection requested
     * @return (String) - the PARAM_REDIRECTION_TYPE parameter - or null if not found
     **/
    public String getRedirectionType(){
        Map<String,String> params = ApexPages.currentPage().getParameters();

        String results = null;
        if( params.containsKey(PARAM_REDIRECTION_TYPE) ){
            results = params.get(PARAM_REDIRECTION_TYPE);
        }

        return( results );
    }

    /**
     * Determines if we should run in DEBUG mode (to validate the redirection)
     * @return (Boolean) - whether we should be in debug (true) or not (false)
     **/
    public Boolean shouldRunInDebugMode(){
        Map<String,String> params = ApexPages.currentPage().getParameters();

        return( params.containsKey(PARAM_DEBUG) );
    }

    /**
     * Determines the parameters used for the redirection.
     * <p>These are used in the string replacelment</p>
     * @return String - Decoded JSON that was received.
     **/
    public String getRedirectionParameters(){
        Map<String,String> params = ApexPages.currentPage().getParameters();

        String paramsStr;
        String tempResults;
        String results = null;
        Map<String, Object> jsonTest;

        if( params.containsKey(PARAM_REDIRECTION_PARAMS) ){
            paramsStr = params.get(PARAM_REDIRECTION_PARAMS);

            System.debug('paramsStr'); System.debug(paramsStr);

            //-- @TODO: investigate whether to return as Map instead of string.
            //-- as we want the decoded JSON values here to use in the debug.

            try {
                tempResults = EncodingUtil.base64Decode(paramsStr).toString();

                jsonTest = (Map<String,Object>)JSON.deserializeUntyped(tempResults);
                
                //-- if successful we know this was base64
                results = tempResults;
            } catch( Exception err){
                System.debug('param:' + PARAM_REDIRECTION_PARAMS + ': was not base64');
            }

            if( results == null ){
                try {
                    tempResults = EncodingUtil.urlDecode(paramsStr, DEFAULT_URL_ENCODING_SCHEME);

                    jsonTest = (Map<String,Object>)JSON.deserializeUntyped(tempResults);
                    
                    //-- if successful we know this was base64
                    results = tempResults;
                } catch( Exception err){
                    System.debug('param:' + PARAM_REDIRECTION_PARAMS + ': was not base64');
                }
            }

            if( results == null ){
                results = DEFAULT_REDIRECTION_PARAMS;
            }

            //-- @TODO: review for better functional place to put this.
        }

        return( results );
    }

    /**
     * Converts a base64 JSON object to a Map<String,String>
     * @param (String) decodedParams
     * @return Map<String,String>
     **/
    public static Map<String,String> convertJSON_toMap(String decodedParams){

        //-- @TODO: investigate whether we can simply use Map<String,Object> instead
        //-- as we can do the string replacement later.

        Map<String,String> results = new Map<String,String>();

        //System.debug('decodedParams'); System.debug(decodedParams);

        try {
            Map<String, Object> jsonObjMap = (Map<String,Object>)JSON.deserializeUntyped(decodedParams);
            //System.debug('jsonMap'); System.debug(String.valueOf(jsonMap));

            String mapValue;
            for( String mapKey : jsonObjMap.keySet() ){
                mapValue = (String)jsonObjMap.get(mapKey);
                results.put(mapKey,mapValue);
            }
        } catch(Exception err){
            System.debug('exception occurred:');
            System.debug(err.getMessage());
        }

        //System.debug('results'); System.debug(results);

        return( results );
    }

    /**
     * Determines whether there is a matching Unified Link Scheme
     * @param (String) schemeName (ExternalId__c of Scheme)
     * @return ltng_UnifiedLinkScheme__c
     **/
    public static ltng_UnifiedLinkScheme__c findUnifiedScheme( String schemeName){
        ltng_UnifiedLinkScheme__c result = null;

        try {
            ltng_UnifiedLinkScheme__c[] matchingSchemes = [ SELECT Id, Name, Description__c, RedirectionPrompt__c,
                UrlSchemeClassic__c, UrlSchemeLightningExperience__c, UrlSchemeMobile__c
                FROM ltng_UnifiedLinkScheme__c
                WHERE ExternalId__c = :schemeName
            ];

            //System.assert(matchingSchemes.size() > 0, 'A matching scheme should be found');
            System.assert(matchingSchemes.size() < 2, 'Only a single matching Scheme must be found:' + schemeName);

            result = matchingSchemes[0];
        } catch( Exception err ){
            System.debug('Exception occurred while finding scheme:' + schemeName + '; ' + err.getMessage());
        }

        return( result );
    }

    /**
     * Replaces map keys within mustache'd strings
     * @param (String) templateString - String with {{key}} replacements.
     * @param Map<String,String> replacement values
     * @return templated String replacements.
     **/
    public static String applyMustacheTemplate( String templateString, Map<String,String> params){
        String result = '' + templateString;

        for( String paramKey : params.keySet() ){
            result = result.replace(
                MUSTACHE_START + paramKey + MUSTACHE_END,
                String.valueOf( params.get(paramKey)))
            ;
        }

        return( result );
    }

    //-- DEBUG MATERIALS

    /**
     * Redirects the Debug Form - to the Debug Page.
     **/
    public PageReference redirectDebugToDebug(){
        return( createRedirect(null, this.debugRedirectType, this.debugRedirectParams, true) );
    }

    /**
     * Redirects the Debug Form - to the target page.
     **/
    public PageReference redirectDebugToTarget(){
        return( createRedirect(null, this.debugRedirectType, this.debugRedirectParams, false) );
    }

    public static PageReference createRedirect( PageReference targetPage, String redirectType, String redirectParams, Boolean includeDebug ){
        PageReference resultReference;

        if( targetPage == null ){
            targetPage = ApexPages.currentPage();
        }

        String result = targetPage.getUrl();
        if( result.indexOf('?') > -1 ){
            result = result.left(result.indexOf('?'));
        }
        //System.debug('result'); System.debug(result);

        result += '?' + PARAM_REDIRECTION_TYPE + '=' + redirectType +
            '&' + PARAM_REDIRECTION_PARAMS + '=' +
            EncodingUtil.base64Encode( Blob.valueOf(redirectParams));
        //System.debug('result'); System.debug(result);

        if( includeDebug ){
            result += '&' + PARAM_DEBUG + '=true';
        }

        resultReference = new PageReference(result);
        resultReference.setRedirect(true);

        return( resultReference );
    }

    /**
     * computes the debug form to calculate a redirect
     * @param includeDebug;
     * @return PageReference
     **/
    public static PageReference calculateRedirect( PageReference targetPage, String redirectType, String redirectParams, Boolean includeDebug ){
        PageReference resultReference;

        if( targetPage == null ){
            targetPage = ApexPages.currentPage();
        }

        String result = targetPage.getUrl();
        if( result.indexOf('?') > -1 ){
            result = result.left(result.indexOf('?'));
        }
        //System.debug('result'); System.debug(result);

        result += '?' + PARAM_REDIRECTION_TYPE + '=' + redirectType +
            '&' + PARAM_REDIRECTION_PARAMS + '=' +
            EncodingUtil.base64Encode( Blob.valueOf(redirectParams));
        //System.debug('result'); System.debug(result);

        if( includeDebug ){
            result += '&' + PARAM_DEBUG + '=true';
        }

        resultReference = new PageReference(result);
        resultReference.setRedirect(true);

        return( resultReference );
    }
}