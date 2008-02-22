//
//  KTMediaManager.h
//  Sandvox
//
//  Copyright (c) 2004-2006, Karelia Software. All rights reserved.
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

// NB: the MediaManager uses two different caches,
// the upload cache maintains a list of all media/images to upload
// the media cache maintains a list of rendered representations to speed performance

#import <Cocoa/Cocoa.h>

@class KTDocument;
@class KTAbstractElement, KTMedia;

@interface KTOldMediaManager : NSObject
{
    KTDocument			*myDocument;
	NSMutableDictionary	*myMediaCache;          // key = uniqueID, value = media object
	NSMutableSet		*myUploadCache;
}

+ (KTOldMediaManager *)mediaManagerWithDocument:(KTDocument *)aDocument;

#pragma mark retrieval

/*! returns array of all KTMediaRef objects in aManagedObjectContext */
- (NSArray *)allMediaRefs:(KTManagedObjectContext *)aManagedObjectContext;

/*! returns array of all KTMediaRef objects where owner == nil in aManagedObjectContext */
- (NSArray *)allMediaRefsWithoutOwners:(KTManagedObjectContext *)aManagedObjectContext;

/*! returns array of all media objects within aManagedObjectContext */
- (NSArray *)allObjects:(KTManagedObjectContext *)aManagedObjectContext;

/*! returns array of media objects with 1 or more media refs in aManagedObjectContext */
- (NSArray *)activeObjects:(KTManagedObjectContext *)aManagedObjectContext;

/*! returns array of all media objects with specified UTI in aManagedObjectContext */
- (NSArray *)objectsOfType:(NSString *)aUTI managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext;

#pragma mark -

- (KTMedia *)objectWithURIRepresentation:(NSURL *)aURL managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext;

- (KTMedia *)objectWithUniqueID:(NSString *)aUniqueID managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext;

- (KTMedia *)objectWithName:(NSString *)aName managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext;

- (KTMedia *)objectWithOriginalPath:(NSString *)aPath managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext;

- (KTMedia *)objectWithOriginalPath:(NSString *)aPath
					   creationDate:(NSCalendarDate *)aCalendarDate
			   managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext;

#pragma mark garbage collection

- (void)collectGarbage;
- (void)removeFromDocument:(KTMedia *)aMediaObject;

#pragma mark publication

/*! returns dict of media to upload (key = filePath, value = data) */
- (NSDictionary *)activeMediaInfo:(KTManagedObjectContext *)aManagedObjectContext;

/*! caches either media or media image object for publication */
- (void)cacheReference:(id)anObject;

- (void)willUploadMedia;
- (void)didUploadMedia;

#pragma mark accessors

- (KTDocument *)document;
- (void)setDocument:(KTDocument *)aDocument;

#pragma mark notifications

- (void)objectDidBecomeActive:(NSNotification *)aNotification;

/*! turns off notifications for [aNotification object] and removes from cache */
- (void)objectDidBecomeInactive:(NSNotification *)aNotification;

#pragma mark support

/*! loads allObjects into mediaCache */
- (void)cacheAllObjects:(KTManagedObjectContext *)aManagedObjectContext;

/*! adds aMediaObject to "live" cache and turns on notifications */
- (void)cacheMedia:(KTMedia *)aMediaObject;

/*! returns name based on aName different from media already in storage */
- (NSString *)uniqueNameWithName:(NSString *)aName managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext;

/*! return a valid media:/ URL given aRelativePath */
- (NSURL *)URLForMediaPath:(NSString *)aRelativePath managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext;

/*! return just the media object referenced by aRelativePath */
- (KTMedia *)objectForMediaPath:(NSString *)aRelativePath managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext;

/*! return the media object and imageName (if any) referenced by aRelativePath
	keys = media, imageName */
- (NSDictionary *)mediaInfoForMediaPath:(NSString *)aRelativePath managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext;

/*! return the MediaRef name for aRelativePath (?ref=), nil if there isn't one */
- (NSString *)refNameForMediaPath:(NSString *)aRelativePath;

- (NSString *)transformMediaReferencesForMediaPaths:(NSSet *)aMediaPathsSet 
									   inHTMLString:(NSString *)html 
											element:(KTElement *)anElement;

// Fix all references to media paths to be relative or absolute as required
- (NSString *)updateMediaReferencesWithinHTMLString:(NSString *)anHTMLString element:(KTElement *)anElement;

- (NSSet *)mediaPathsWithinHTMLString:(NSString *)anHTMLString;
- (NSArray *)namesOfMediaReferencesWithinHTMLString:(NSString *)anHTMLString;

@end
