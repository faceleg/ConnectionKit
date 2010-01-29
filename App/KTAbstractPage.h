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

#import "SVSiteItem.h"
#import "SVPageProtocol.h"
#import "KTWebPathsProtocol.h"


typedef enum	//	Defines the 3 ways of linking to a collection:
{
	KTCollectionDirectoryPath,			//		collection
	KTCollectionHTMLDirectoryPath,		//		collection/
	KTCollectionIndexFilePath,			//		collection/index.html
}
KTCollectionPathStyle;


@class KTPage, KTSite, KTMaster, SVSidebar, SVTitleBox;
@class SVHTMLTemplateParser;


@interface KTAbstractPage : SVSiteItem <SVPage>

+ (NSString *)entityName;
+ (NSArray *)allPagesInManagedObjectContext:(NSManagedObjectContext *)MOC;
+ (id)pageWithUniqueID:(NSString *)pageID inManagedObjectContext:(NSManagedObjectContext *)MOC;

+ (id)pageWithParent:(KTPage *)aParent entityName:(NSString *)entityName;


#pragma mark Identifier
@property(nonatomic, copy, readonly) NSString *uniqueID;


#pragma mark Child Pages

@property(nonatomic, copy, readonly) NSSet *archivePages;
- (BOOL)isCollection;

- (BOOL)isRoot;


#pragma mark Other Relationships
- (KTSite *)site;
- (KTMaster *)master;

@property(nonatomic, retain, readonly) SVSidebar *sidebar;


#pragma mark Web
- (NSString *)pageMainContentTemplate;	// instance method too for key paths to work in tiger

- (void)writeHTML;  // prepares the current HTML context (XHTML, encoding etc.), then writes to it
- (NSString *)HTMLString;   // creates a temporary HTML context and calls -writeHTML for PUBLISHING

- (BOOL)isXHTML;

// Comments
- (NSString *)JSKitPath;

// Staleness
- (BOOL)isStale;
- (void)setIsStale:(BOOL)stale;

- (NSData *)publishedDataDigest;
- (void)setPublishedDataDigest:(NSData *)digest;


@end


#pragma mark -


@interface KTAbstractPage (ForSubclassesToImplement)
// Meta tags
@property(nonatomic, copy) NSString *metaDescription;
@property(nonatomic, copy) NSString *windowTitle;
@end


#pragma mark -


@interface KTAbstractPage (Paths) <KTWebPaths>

// File Name
@property(nonatomic, copy, readwrite) NSString *fileName;
- (NSString *)suggestedFileName;


#pragma mark Path Extension
// TODO: Rename other methods to follow this scheme
@property(nonatomic, copy, readonly) NSString *pathExtension;

@property(nonatomic, copy) NSNumber *fileExtensionIsEditable;   // BOOL, non-optional

- (NSString *)defaultFileExtension;
- (NSArray *)availableFileExtensions;


// Summat else
- (NSString *)indexFilename;
- (NSString *)indexFileName;
- (NSString *)archivesFilename;


// Publishing
- (void)recursivelyInvalidateURL:(BOOL)recursive;

- (NSString *)uploadPath;

// Preview
- (NSString *)previewPath;

@end
