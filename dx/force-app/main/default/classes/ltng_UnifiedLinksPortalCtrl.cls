/**
 * Controller for the ltng_UnifiedLinks page.
 * <p>To see the URL Schemes available for Lightning Experience, see:
 *    https://developer.salesforce.com/docs/atlas.en-us.lightning.meta/lightning/components_navigation_page_definitions.htm
 * </p>
 * <p>To see the URL schemes available for Salesforce1, see:
 *    https://resources.docs.salesforce.com/208/latest/en-us/sfdc/pdf/salesforce1_url_schemes.pdf
 * </p>
 * @class ltng_UnifiedLinksPortalCtrl
 **/
public with sharing class ltng_UnifiedLinksPortalCtrl {

    /** Permission that determines if the user has access to LEX **/
    public static final String PERM_LEX_ENABLED = 'LightningExperienceUser';

    /** Default page to redirect someone to **/
    public static final String DEFAULT_REDIRECTION = '/a00';
    /** Default prompt for redirection **/
    public static final String DEFAULT_REDIRECTION_PROMPT = 'We were unable to redirect you. Please contact your administrator';

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
        Map<String,String> redirectionParams = getRedirectionParameters();
        String redirectionTemplate;

        this.redirectionPrompt = DEFAULT_REDIRECTION_PROMPT;
        this.redirectionURL = DEFAULT_REDIRECTION;
        this.debugMode = shouldRunInDebugMode();

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
     * @return Map<String,String> - map from the base64 decoded parameters sent.
     **/
    public Map<String,String> getRedirectionParameters(){
        Map<String,String> params = ApexPages.currentPage().getParameters();

        String paramsStr;
        Map<String,String> results = new Map<String,String>();

        if( params.containsKey(PARAM_REDIRECTION_PARAMS) ){
            paramsStr = params.get(PARAM_REDIRECTION_PARAMS);

            System.debug('paramsStr'); System.debug(paramsStr);

            results = convertJSON_toMap(paramsStr);
        }

        return( results );
    }

    /**
     * Converts a base64 JSON object to a Map<String,String>
     * @param (String) base64JSON
     * @return Map<String,String>
     **/
    public static Map<String,String> convertJSON_toMap(String base64JSON){

        //-- @TODO: investigate whether we can simply use Map<String,Object> instead
        //-- as we can do the string replacement later.

        Map<String,String> results = new Map<String,String>();

        System.debug('base64JSON'); System.debug(base64JSON);

        //try {
            String decodedStr = EncodingUtil.base64Decode(base64JSON).toString();
            //System.debug('decodedStr'); System.debug(String.valueOf(decodedStr));
            Map<String, Object> jsonObjMap = (Map<String,Object>)JSON.deserializeUntyped(decodedStr);
            //System.debug('jsonMap'); System.debug(String.valueOf(jsonMap));

            String mapValue;
            for( String mapKey : jsonObjMap.keySet() ){
                mapValue = (String)jsonObjMap.get(mapKey);
                results.put(mapKey,mapValue);
            }
        //} catch(Exception err){
        //    System.debug('exception occurred:');
        //    System.debug(err.getMessage());
        //}

        System.debug('results'); System.debug(results);

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
     * computes the debug form to calculate a redirect
     * @return PageReference
     **/
    public PageReference calculateRedirect(){

        this.redirectionURL = ApexPages.currentPage().getUrl();
        if( this.redirectionURL.indexOf('?') > -1 ){
            this.redirectionURL = this.redirectionURL.left(this.redirectionURL.indexOf('?'));
        }
        System.debug('this.redirectionURL'); System.debug(this.redirectionURL);

        this.redirectionURL += '?' + PARAM_DEBUG + '=true&' +
            PARAM_REDIRECTION_TYPE + '=' + this.debugRedirectType +
            '&' + PARAM_REDIRECTION_PARAMS + '=' +
            EncodingUtil.base64Encode( Blob.valueOf(this.debugRedirectParams));
        System.debug('redirectionURL'); System.debug(this.redirectionURL);

        PageReference result = new PageReference(this.redirectionURL);
        result.setRedirect(true);

        return( result );
    }
}