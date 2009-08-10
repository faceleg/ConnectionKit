//
//  KTDataMigrator.h
//  KTComponents
//
//  Copyright 2005-2009 Karelia Software. All rights reserved.
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
    
    NSURL       *myMigratedDocumentURL;
    KTDocument  *myMigratedDocument;
    
    unsigned    myCountOfPagesToMigrate;
    unsigned    myCountOfPagesMigrated;
    BOOL        myIsCancelled;
}

+ (NSString *)renamedFileName:(NSString *)originalFileNameWithExtension modelVersion:(NSString *)aVersion;
+ (NSString *)currentPluginIdentifierForOldIdentifier:(NSString *)oldIdentifier;

// Init
- (id)initWithDocumentURL:(NSURL *)docURL;

// Accessors
- (NSURL *)oldStoreURL;
- (NSManagedObjectModel *)oldManagedObjectModel;
- (NSManagedObjectContext *)oldManagedObjectContext;

- (NSURL *)migratedDocumentURL;
- (KTDocument *)migratedDocument;

- (unsigned)countOfPagesToMigrate;
- (unsigned)countOfPagesMigrated;

// Migration
- (BOOL)migrate:(NSError **)error;

- (void)migrateWithDelegate:(id)delegate            // Asynchronous version
         didMigrateSelector:(SEL)didMigrateSelector
                contextInfo:(void *)contextInfo;

- (void)cancel;
- (BOOL)isCancelled;

@end


#import "KTAbstractElement.h"
@interface KTAbstractElement (KTDataMigratorAdditions)

- (BOOL)importPluginProperties:(NSDictionary *)oldPluginProperties
                    fromPlugin:(NSManagedObject *)oldPlugin
                         error:(NSError **)error;

@end