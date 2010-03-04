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
@class KTMediaContainer, KTMediaFile;


@interface KTMediaManager : NSObject
{
	KTDocument  *_document;    // weak ref
    
    NSMutableDictionary *myMediaContainerIdentifiersCache;
}

// Basic Accesors
- (KTDocument *)document;

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


@interface KTMediaManager (Internal)

// designated initializer
- (id)initWithDocument:(KTDocument *)document;



// Missing media
- (NSSet *)missingMediaFiles;


- (void)garbageCollect;


@end

/*	At the lowest level of the system is raw KTMediaFile management. Media Files are simple objects that
 *	represent a single unique piece of media, internal or external to the document. Code outside the media
 *	system should never have to manage KTMediaFile objects directly; the higher-level APIs do that.
 */
@interface KTMediaManager (MediaFilesInternal)

// Queries
- (NSArray *)externalMediaFiles;
- (KTMediaFile *)mediaFileWithIdentifier:(NSString *)identifier;

// MediaFile creation/re-use
- (KTMediaFile *)mediaFileWithPath:(NSString *)path;
- (KTMediaFile *)mediaFileWithPath:(NSString *)path preferExternalFile:(BOOL)preferExternal;
- (KTMediaFile *)mediaFileWithData:(NSData *)data preferredFilename:(NSString *)filename;
- (KTMediaFile *)mediaFileWithImage:(NSImage *)image;
- (KTMediaFile *)mediaFileWithDraggingInfo:(id <NSDraggingInfo>)info preferExternalFile:(BOOL)preferExternal;

@end


@interface NSManagedObject (MediaManagerGarbageCollector)
- (NSSet *)requiredMediaIdentifiers;
@end
