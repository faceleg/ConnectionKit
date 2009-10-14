//
//  KTAbstractPage.h
//  Sandvox
//
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import <Cocoa/Cocoa.h>
#import "KTAbstractElement.h"
#import "KTWebPathsProtocol.h"


typedef enum	//	Defines the 3 ways of linking to a collection:
{
	KTCollectionDirectoryPath,			//		collection
	KTCollectionHTMLDirectoryPath,		//		collection/
	KTCollectionIndexFilePath,			//		collection/index.html
}
KTCollectionPathStyle;


@class KTSite, KTMaster, SVSidebar;
@class SVHTMLTemplateParser;


@interface KTAbstractPage : KTAbstractElement

+ (NSString *)entityName;
+ (NSArray *)allPagesInManagedObjectContext:(NSManagedObjectContext *)MOC;
+ (id)pageWithUniqueID:(NSString *)pageID inManagedObjectContext:(NSManagedObjectContext *)MOC;

+ (id)pageWithParent:(KTPage *)aParent entityName:(NSString *)entityName;

#pragma mark Relationships
- (KTPage *)parent;
- (BOOL)isCollection;
- (BOOL)isRoot;
- (BOOL)isDescendantOfPage:(KTAbstractPage *)aPotentialAncestor;

- (KTSite *)site;

- (KTMaster *)master;

@property(nonatomic, retain, readonly) SVSidebar *sidebar;


#pragma mark Title
- (BOOL)canEditTitle;

#pragma mark Web
- (NSString *)pageMainContentTemplate;	// instance method too for key paths to work in tiger
- (NSString *)contentHTMLWithParserDelegate:(id)delegate isPreview:(BOOL)isPreview;
- (BOOL)isXHTML;

// Meta tags
- (NSString *)metaDescription;
- (void)setMetaDescription:(NSString *)description;
- (NSString *)windowTitle;
- (void)setWindowTitle:(NSString *)wTitle;

// Comments
- (NSString *)JSKitPath;

// Staleness
- (BOOL)isStale;
- (void)setIsStale:(BOOL)stale;

- (NSData *)publishedDataDigest;
- (void)setPublishedDataDigest:(NSData *)digest;


@end


@interface KTAbstractPage (Paths) <KTWebPaths>

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
- (NSURL *)URL;
- (void)recursivelyInvalidateURL:(BOOL)recursive;

- (NSString *)customPathRelativeToSite;
- (void)setCustomPathRelativeToSite:(NSString *)path;

- (NSString *)uploadPath;

- (NSString *)publishedPath;
- (void)setPublishedPath:(NSString *)path;

// Preview
- (NSString *)previewPath;

@end
