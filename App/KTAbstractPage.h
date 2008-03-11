//
//  KTAbstractPage.h
//  Marvel
//
//  Created by Mike on 28/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTAbstractElement.h"

#import "KTWebViewComponent.h"


typedef enum	//	Defines the 3 ways of linking to a collection:
{
	KTCollectionDirectoryPath,			//		collection
	KTCollectionHTMLDirectoryPath,		//		collection/
	KTCollectionIndexFilePath,			//		collection/index.html
}
KTCollectionPathStyle;


@interface KTAbstractPage : KTAbstractElement <KTWebViewComponent>
{
}

+ (NSString *)entityName;
+ (NSArray *)allPagesInManagedObjectContext:(NSManagedObjectContext *)MOC;
+ (id)pageWithUniqueID:(NSString *)ID inManagedObjectContext:(NSManagedObjectContext *)MOC;

+ (id)pageWithParent:(KTPage *)aParent entityName:(NSString *)entityName;

- (KTPage *)parent;
- (BOOL)isCollection;
- (BOOL)isRoot;

- (BOOL)isStale;
- (void)setIsStale:(BOOL)stale;

// Title
- (void)setTitleHTML:(NSString *)value;
- (NSString *)titleText;
- (void)setTitleText:(NSString *)value;
- (BOOL)canEditTitle;

+ (NSString *)pageMainContentTemplate;
- (NSString *)contentHTMLWithParserDelegate:(id)delegate isPreview:(BOOL)isPreview;

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
- (NSURL *)publishedURL;
- (NSURL *)publishedURLAllowingIndexPage:(BOOL)aCanHaveIndexPage;
- (NSString *)publishedPathRelativeToParent;
- (NSString *)publishedPathRelativeToSite;
- (NSString *)publishedPathRelativeToPage:(KTAbstractPage *)otherPage;

// Uploading
- (NSString *)uploadPath;
- (NSString *)uploadPathRelativeToParent;

// Preview
- (NSString *)previewPath;

// Other
- (NSString *)publishedPathForResourceFile:(NSString *)resourcePath;
- (NSString *)designDirectoryPath;

@end

