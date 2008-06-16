//
//  KTAbstractPage.h
//  Marvel
//
//  Created by Mike on 28/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTAbstractElement.h"

#import "KTWebPathsProtocol.h"
#import "KTWebViewComponent.h"


typedef enum	//	Defines the 3 ways of linking to a collection:
{
	KTCollectionDirectoryPath,			//		collection
	KTCollectionHTMLDirectoryPath,		//		collection/
	KTCollectionIndexFilePath,			//		collection/index.html
}
KTCollectionPathStyle;


@class KTDocumentInfo;


@interface KTAbstractPage : KTAbstractElement <KTWebPaths, KTWebViewComponent>
{
}

+ (NSString *)entityName;
+ (NSArray *)allPagesInManagedObjectContext:(NSManagedObjectContext *)MOC;
+ (id)pageWithUniqueID:(NSString *)ID inManagedObjectContext:(NSManagedObjectContext *)MOC;

+ (id)pageWithParent:(KTPage *)aParent entityName:(NSString *)entityName;

- (KTPage *)parent;
- (BOOL)isCollection;
- (BOOL)isRoot;

- (KTDocumentInfo *)documentInfo;

- (BOOL)isStale;
- (void)setIsStale:(BOOL)stale;

// Title
- (void)setTitleHTML:(NSString *)value;
- (NSString *)titleText;
- (void)setTitleText:(NSString *)value;
- (BOOL)canEditTitle;

// Web
- (NSString *)pageMainContentTemplate;	// instance method too for key paths to work in tiger
- (NSString *)contentHTMLWithParserDelegate:(id)delegate isPreview:(BOOL)isPreview;

- (NSString *)fixPageLinksFromString:(NSString *)originalString managedObjectContext:(NSManagedObjectContext *)context;

// Notifications
- (void)postSiteStructureDidChangeNotification;

@end


@interface KTAbstractPage (Paths)

// File Name
- (NSString *)fileName;
- (void)setFileName:(NSString *)fileName;
- (NSString *)suggestedFileName;


// File Extension
- (NSString *)fileExtension;

- (NSString *)customFileExtension;
- (void)setCustomFileExtension:(NSString *)extension;

- (BOOL)fileExtensionIsEditable;
- (void)setFileExtensionIsEditable:(BOOL)editable;

- (NSString *)defaultFileExtension;
- (NSArray *)availableFileExtensions;


// Summat else
- (NSString *)indexFilename;
- (NSString *)indexFileName;
- (NSString *)archivesFilename;


// Publishing
- (NSString *)pathRelativeToParent;
- (void)recursivelyInvalidateURL:(BOOL)recursive;

- (NSString *)customPathRelativeToSite;
- (void)setCustomPathRelativeToSite:(NSString *)path;

- (NSString *)uploadPath;

// Preview
- (NSString *)previewPath;

@end

