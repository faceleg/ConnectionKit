
// Document
NSString *kKTDocumentType = @"Sandvox Document";
NSString *kKTDocumentExtension = @"svxSite";
NSString *kKTDocumentUTI = @"com.karelia.sandvox.site-document";
NSString *kKTDocumentUTI_ORIGINAL = @"com.karelia.sandvox.document";

NSString *kKTPageIDDesignator = @"~PAGEID~";

// Spotlight metadata keys
NSString *kKTMetadataAppCreatedVersionKey = @"com_karelia_Sandvox_AppCreatedVersion"; // CFBundleVersion which created document
NSString *kKTMetadataAppLastSavedVersionKey = @"com_karelia_Sandvox_AppLastSavedVersion"; // CFBundleVersion which last saved document
NSString *kKTMetadataModelVersionKey = @"com_karelia_Sandvox_ModelVersion";

// Core Data
NSString *kKTModelVersion = @"15001";
NSString *kKTModelVersion_ORIGINAL = @"10002";
NSString *kKTModelMinimumVersion = @"10002"; // we'll support models >= this
NSString *kKTModelMaximumVersion = @"15001"; // we'll support models <= this

// DataSources
NSString *kKTDataSourceRecurse = @"kKTDataSourceRecurse";
NSString *kKTDataSourceFileName = @"kKTDataSourceFileName";
NSString *kKTDataSourceFilePath = @"kKTDataSourceFilePath";
NSString *kKTDataSourceTitle = @"kKTDataSourceTitle";
NSString *kKTDataSourceCaption = @"kKTDataSourceCaption";
NSString *kKTDataSourceURLString = @"kKTDataSourceURLString";
NSString *kKTDataSourceImageURLString = @"kKTDataSourceImageURLString";
NSString *kKTDataSourcePreferExternalImageFlag = @"kKTDataSourcePreferExternalImageFlag";
NSString *kKTDataSourceShouldIncludeLinkFlag = @"kKTDataSourceShouldIncludeLinkFlag";
NSString *kKTDataSourceLinkToOriginalFlag = @"kKTDataSourceLinkToOriginalFlag";
NSString *kKTDataSourceFeedURLString = @"kKTDataSourceFeedURLString";
NSString *kKTDataSourcePlugin = @"kKTDataSourcePlugin";
NSString *kKTDataSourceImage = @"kKTDataSourceImage";
NSString *kKTDataSourceString = @"kKTDataSourceString";
NSString *kKTDataSourceData = @"kKTDataSourceData";
NSString *kKTDataSourceUTI = @"kKTDataSourceUTI";
NSString *kKTDataSourceCreationDate = @"kKTDataSourceCreationDate";
NSString *kKTDataSourceKeywords = @"kKTDataSourceKeywords";
NSString *kKTDataSourcePasteboard = @"kKTDataSourcePasteboard";
NSString *kKTDataSourceNil = @"kKTDataSourceNil";

// Error Domains
NSString *kKTDataMigrationErrorDomain = @"com.karelia.Sandvox.DataMigrationErrorDomain";
NSString *kKTHostSetupErrorDomain = @"com.karelia.Sandvox.HostSetupErrorDomain";
NSString *kKTConnectionErrorDomain = @"com.karelia.Sandvox.ConnectionErrorDomain";

// Exceptions
NSString *kKTTemplateParserException = @"KTTemplateParserException";

// Pasteboards
NSString *kKTOutlineDraggingPboardType = @"KTOutlineDraggingPboardType";
NSString *kKTPagesPboardType = @"KTPagesPboardType";
NSString *kKTPageletsPboardType = @"KTPageletsPboardType";

// Plugin Extensions
NSString *kKTIndexExtension = @"svxIndex";
NSString *kKTElementExtension = @"svxElement";
NSString *kKTDesignExtension = @"svxDesign";

// Notifications
NSString *kKTDesignChangedNotification = @"kKTDesignChangedNotification";
NSString *kKTInfoWindowMayNeedRefreshingNotification = @"KTInfoWindowMayNeedRefreshingNotification";

// Site Publication
NSString *kKTDefaultMediaPath = @"_Media";
NSString *kKTDefaultResourcesPath = @"_Resources";

NSString *kKTInternalImageClassName = @"InternalImageClassName";
