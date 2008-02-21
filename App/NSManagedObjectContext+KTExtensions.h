//
//  NSManagedObjectContext+KTExtensions.h
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

@class KTAbstractPlugin, KTDocument, KTDocumentInfo, KTManagedObject, KTMedia, KTPage;

@interface NSManagedObjectContext ( KTExtensions )

#pragma mark genernal NSManagedObjectContext extensions

/*! returns set of all updated, inserted, and deleted objects in context */
- (NSSet *)changedObjects;

- (void)deleteObjects:(NSSet *)objects;

- (void)lockPSCAndSelf;
- (void)unlockPSCAndSelf;

- (NSArray *)objectsWithFetchRequestTemplateWithName:(NSString *)aTemplateName
							   substitutionVariables:(NSDictionary *)aDictionary
											   error:(NSError **)anError;

// returns array of objects in context matching criteria
// (functions as thread-safe executeFetchRequest: method)
- (NSArray *)objectsWithEntityName:(NSString *)anEntityName
						 predicate:(NSPredicate *)aPredicate
							 error:(NSError **)anError;

// returns an array of all objects of anEntityName (by using a nil predicate)
- (NSArray *)allObjectsWithEntityName:(NSString *)anEntityName
								error:(NSError **)anError;

// returns object corresponding to NSManagedObjectID's URIRepresentation
- (NSManagedObject *)objectWithURIRepresentation:(NSURL *)aURL;

// returns object corresponding to NSString of NSManagedObjectID's URIRepresentation
- (NSManagedObject *)objectWithURIRepresentationString:(NSString *)aURIRepresentationString;

// returns array of unique values for aColumnName for all instances of anEntityName
- (NSArray *)objectsForColumnName:(NSString *)aColumnName entityName:(NSString *)anEntityName;

#pragma mark methods Sandvox-specific extensions

// returns corresponding KTDocument via sharedDocumentController
// (document must be open and on-screen)
- (KTDocument *)document;

// return context's DocumentInfo
- (KTDocumentInfo *)documentInfo;

// return YES if self is a known KTDocument MOC (rather than a peer MOC)
- (BOOL)isDocumentMOC;

// returns KTMedia object matching digest(s), nil is taken into account
- (KTMedia *)objectMatchingMediaDigest:(NSString *)aMediaDigest
					   thumbnailDigest:(NSString *)aThumbnailDigest;

// returns KTManagedObject in context matching criteria 
- (KTManagedObject *)objectWithUniqueID:(NSString *)aUniqueID entityNames:(NSArray *)aNamesArray;
- (KTManagedObject *)objectWithUniqueID:(NSString *)aUniqueID entityName:(NSString *)anEntityName;

// returns KTManagedObject, searching entities Root, Page, Pagelet, Element, and Media
- (KTManagedObject *)objectWithUniqueID:(NSString *)aUniqueID;
- (KTAbstractPlugin *)pluginWithUniqueID:(NSString *)pluginID;

// returns objectWithUniqueID: searching only Media
- (KTMedia *)mediaWithUniqueID:(NSString *)anID;

// returns objectWithUniqueID: searching only Page
- (KTPage *)pageWithUniqueID:(NSString *)anID;

// returns context's Root
- (KTPage *)root;
- (NSArray *)allPages;

- (void)makeAllPluginsPerformSelector:(SEL)selector withObject:(id)object withPage:(KTPage *)page;
@end
