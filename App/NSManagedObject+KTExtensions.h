//
//  NSManagedObject+KTExtensions.h
//  Sandvox
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

- (BOOL)hasChanges;

- (NSUndoManager *)undoManager;

#pragma mark KVC
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

/* Non-standard, transient attributes */
- (id)transientValueForKey:(NSString *)key persistentPropertyListKey:(NSString *)plistKey;
- (void)setTransientValue:(id)value forKey:(NSString *)key persistentPropertyListKey:(NSString *)plistKey;

- (id)transientValueForKey:(NSString *)key persistentArchivedDataKey:(NSString *)dataKey;
- (void)setTransientValue:(id)value forKey:(NSString *)key persistentArchivedDataKey:(NSString *)dataKey;


#pragma mark Serialization

// Default implemention creates a mutable dictionary and passes it to -populateSerializedValues:. Override to use something other than a dictionary, or create a mutable dictionary with the right capacity.
- (id)serializedProperties;

// Calls [self serializedValueForKey:] with each non-transient attribute. Override to add in any relationships and custom properties
- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;   

- (id)serializedValueForKey:(NSString *)key;    // MUST return a plist object. Override to handle invalid types
- (void)setSerializedValue:(id)serializedValue forKey:(NSString*)key;

- (void)awakeFromPropertyList:(id)propertyList;

@end
