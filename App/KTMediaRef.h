//
//  KTMediaRef.h
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

#import "KTManagedObject.h"



@class KTAbstractElement, KTMedia;
@interface KTMediaRef : KTManagedObject
{

}

/*	Those media refs that plugins SHOULDN'T use */
+ (NSSet *)reservedMediaRefNames;

/*! standard constructor, assumes that instance will be created in aMediaObject's context */
+ (KTMediaRef *)mediaRefWithMedia:(KTMedia *)aMediaObject
                             name:(NSString *)aName
                            owner:(KTAbstractElement *)anOwner;

/*! constructor for reconstituting MediaRef from a dictionary (generally via the pasteboard) */
+ (KTMediaRef *)mediaRefWithArchiveDictionary:(NSDictionary *)aDictionary
										owner:(KTAbstractElement *)anOwner;

/*! "retain" media by creating a new KTMediaRef in aMediaObject's context
	(any previous mediaRef(s) with same aName and anOwner are released)
*/
+ (KTMediaRef *)retainMedia:(KTMedia *)aMediaObject
                       name:(NSString *)aName
                      owner:(KTAbstractElement *)anOwner;

/*! "release" media by deleting KTMediaRef that corresponds to parameters */
+ (void)releaseMediaRef:(KTMediaRef *)aMediaRef;

+ (BOOL)releaseMedia:(KTMedia *)aMediaObject
                name:(NSString *)aName
			   owner:(KTAbstractElement *)anOwner;

/*! returns KTMediaRef matching parameters from aMediaObject's context */
+ (KTMediaRef *)objectMatchingMedia:(KTMedia *)aMediaObject
                               name:(NSString *)aName
                              owner:(KTAbstractElement *)anOwner;

/*! returns media relationship */
- (KTMedia *)media;

/*! returns name of this KTMediaRef */
- (NSString *)name;

/*! returns media's document */
- (KTDocument *)document;

- (NSString *)enclosureURL;

// for the rest of this object, we override forwardInvocation:
// and pass messages on to the instance's corresponding media object
//
// the idea here is to let a mediaRef "stand-in" for a media object
// but have the underlying media object do the heavy lifting for
// data storage, image scaling, etc.

// NB: deleting a KTMediaRef does not delete the underlying media object
//     for that, KTMediaManager's garbage collection routine sweeps at window
//     close looking for KTMedia objects that have no corresponding KTMediaRefs

// we do this so that KTMedia objects no longer have to track their
// own clients, making it easy to move them between contexts

@end
