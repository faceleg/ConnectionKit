//
//  KTDataMigrator.h
//  KTComponents
//
//  Copyright (c) 2005-2006, Karelia Software. All rights reserved.
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


@class KTDocument;


@interface KTDataMigrator : NSObject 
{
	NSManagedObjectModel	*myOldManagedObjectModel;
	NSManagedObjectContext	*myOldManagedObjectContext;
	NSURL					*myOldStoreURL;
    
    NSURL       *myNewDocumentURL;
    KTDocument  *myNewDocument;
	
	NSMutableDictionary		*myObjectIDCache; // key = old objectID, value = new objectID
}

// this is the main entry point to migrate a file
+ (BOOL)upgradeDocumentWithURL:(NSURL *)aStoreURL modelVersion:(NSString *)aVersion error:(NSError **)outError;

// this returns the fileName that the original file will be renamed to
+ (NSString *)renamedFileName:(NSString *)originalFileNameWithExtension modelVersion:(NSString *)aVersion;

+ (NSString *)newPluginIdentifierForOldPluginIdentifier:(NSString *)oldIdentifier;


// Accessors
- (NSManagedObjectModel *)oldManagedObjectModel;
- (void)setOldManagedObjectModel:(NSManagedObjectModel *)anOldManagedObjectModel;

- (NSManagedObjectContext *)oldManagedObjectContext;
- (void)setOldManagedObjectContext:(NSManagedObjectContext *)anOldManagedObjectContext;

- (NSURL *)oldStoreURL;
- (void)setOldStoreURL:(NSURL *)aStoreURL;

- (NSURL *)newDocumentURL;
- (void)setNewDocumentURL:(NSURL *)URL;

- (KTDocument *)newDocument;
- (void)setNewDocument:(KTDocument *)document;

- (NSManagedObjectModel *)newManagedObjectModel;
- (NSManagedObjectContext *)newManagedObjectContext;

- (NSMutableDictionary *)objectIDCache;
- (void)setObjectIDCache:(NSMutableDictionary *)anObjectIDCache;


// This is the workhorse
- (BOOL)genericallyMigrateDataFromOldModelVersion:(NSString *)aVersion error:(NSError **)error;

@end


#import "KTAbstractElement.h"
@interface KTAbstractElement (KTDataMigratorAdditions)
- (void)importOldPluginProperties:(NSDictionary *)oldPluginProperties dataMigrator:(KTDataMigrator *)dataMigrator;
@end