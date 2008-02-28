//
//  KTAbstractPage.h
//  Marvel
//
//  Created by Mike on 28/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTAbstractElement.h"


typedef enum	//	Defines the 3 ways of linking to a collection:
{
	KTCollectionDirectoryPath,			//		collection
	KTCollectionHTMLDirectoryPath,		//		collection/
	KTCollectionIndexFilePath,			//		collection/index.html
}
KTCollectionPathStyle;


@interface KTAbstractPage : KTAbstractElement {

}

- (KTPage *)parent;
- (BOOL)isCollection;
- (BOOL)isRoot;

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
- (NSString *)defaultFileExtension;
- (NSArray *)availableFileExtensions;

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
- (NSString *)archivesURLPathRelativeToPage:(KTAbstractPage *)aPage;

@end

