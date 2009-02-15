//
//  KTMediaManager.h
//  Sandvox
//
//  Copyright 2007-2009 Karelia Software. All rights reserved.
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


extern NSString *KTMediaLogDomain;


@class KTDocument, KTAbstractElement;
@class KTMediaContainer;

@interface KTMediaManager : NSObject
{
	KTDocument				*myDocument;    // Weak ref
	NSManagedObjectContext	*myMOC;
    
    NSMutableDictionary *myMediaContainerIdentifiersCache;
}

// Basic Accesors
+ (NSString *)defaultMediaStoreType;
+ (NSURL *)mediaURLForDocumentURL:(NSURL *)inURL;
+ (NSURL *)mediaStoreURLForDocumentURL:(NSURL *)inURL;
+ (NSManagedObjectModel *)managedObjectModel;

- (KTDocument *)document;
- (NSManagedObjectContext *)managedObjectContext;
- (NSString *)mediaPath;
- (NSString *)temporaryMediaPath;

@end


@interface KTMediaManager (MediaFiles)
- (BOOL)mediaFileShouldBeExternal:(NSString *)path;
+ (BOOL)fileConstitutesIMedia:(NSString *)path;
@end


@interface KTMediaManager (MediaContainers)

// Media Container Creation
- (KTMediaContainer *)mediaContainerWithIdentifier:(NSString *)identifier;

- (KTMediaContainer *)mediaContainerWithPath:(NSString *)path;
- (KTMediaContainer *)mediaContainerWithURL:(NSURL *)aURL;
- (KTMediaContainer *)mediaContainerWithData:(NSData *)data filename:(NSString *)filename fileExtension:(NSString *)extension;
- (KTMediaContainer *)mediaContainerWithData:(NSData *)data filename:(NSString *)filename UTI:(NSString *)UTI;
- (KTMediaContainer *)mediaContainerWithImage:(NSImage *)image;
- (KTMediaContainer *)mediaContainerWithDraggingInfo:(id <NSDraggingInfo>)dragInfo preferExternalFile:(BOOL)external;
- (KTMediaContainer *)mediaContainerWithDataSourceDictionary:(NSDictionary *)dataSource;

// Scaling
- (BOOL)scaledImageContainersShouldGenerateMediaFiles;

@end


@interface KTMediaManager (LegacySupport)

- (KTMediaContainer *)mediaContainerWithMediaRefNamed:(NSString *)oldMediaRefName element:(NSManagedObject *)oldElement;

- (NSString *)importLegacyMediaFromString:(NSString *)oldText
                      scalingSettingsName:(NSString *)scalingSettings
                               oldElement:(NSManagedObject *)oldElement
                               newElement:(KTAbstractElement *)newElement;

@end


@interface NSManagedObject (MediaManagerGarbageCollector)
- (NSSet *)requiredMediaIdentifiers;
@end
