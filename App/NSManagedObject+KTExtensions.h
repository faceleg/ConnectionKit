//
//  NSManagedObject+KTExtensions.h
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


@interface NSManagedObject ( KTExtensions )

- (BOOL)hasAttributeNamed:(NSString *)anAttributeName;
- (BOOL)hasRelationshipNamed:(NSString *)aRelationshipName;

/*! checks that self is able to fetch a value for aKey */
- (BOOL)isValidForKey:(NSString *)aKey;

/*! returns EntityName:URIRepresentation */
- (NSString *)managedObjectDescription;

/*! returns URIRepresentation as NSString */
- (NSString *)URIRepresentationString;

/*! returns all values (changed+committed) */
- (NSDictionary *)currentValues;

- (BOOL)hasTemporaryObjectID;
- (BOOL)hasTemporaryURIRepresentation;
- (BOOL)isTemporaryObject;
- (BOOL)isNewlyCreatedObject;

- (BOOL)hasChanges;

- (id)committedValueForKey:(NSString *)aKey;
- (id)persistentValueForKey:(NSString *)aKey;

- (id)wrappedValueForKey:(NSString *)aKey;
- (void)setWrappedValue:(id)aValue forKey:(NSString *)aKey;
- (BOOL)wrappedBoolForKey:(NSString *)aKey;
- (void)setWrappedBool:(BOOL)value forKey:(NSString *)aKey;
- (float)wrappedFloatForKey:(NSString *)aKey;
- (void)setWrappedFloat:(float)value forKey:(NSString *)aKey;
- (int)wrappedIntegerForKey:(NSString *)aKey;
- (void)setWrappedInteger:(int)value forKey:(NSString *)aKey;

- (id)delegableWrappedValueForKey:(NSString *)aKey;
- (void)setDelegableWrappedValue:(id)aValue forKey:(NSString *)aKey;

- (id)threadSafeWrappedValueForKey:(NSString *)aKey;
- (void)threadSafeSetWrappedValue:(id)aValue forKey:(NSString *)aKey;

- (id)threadSafeValueForKey:(NSString *)aKey;
- (void)threadSafeSetValue:(id)aValue forKey:(NSString *)aKey;

- (id)threadSafeValueForKeyPath:(NSString *)aKeyPath;
- (void)threadSafeSetValue:(id)aValue forKeyPath:(NSString *)aKeyPath;

- (void)lockContext;
- (void)unlockContext;

- (BOOL)lockContextIfNeeded;
- (void)unlockContextIfNeeded:(BOOL)didLock;

- (void)lockPSCAndMOC;
- (void)unlockPSCAndMOC;

/* Non-standard, transient attributes */
- (id)transientValueForKey:(NSString *)key persistentPropertyListKey:(NSString *)plistKey;
- (void)setTransientValue:(id)value forKey:(NSString *)key persistentPropertyListKey:(NSString *)plistKey;

- (id)transientValueForKey:(NSString *)key persistentArchivedDataKey:(NSString *)dataKey;
- (void)setTransientValue:(id)value forKey:(NSString *)key persistentArchivedDataKey:(NSString *)dataKey;

@end
