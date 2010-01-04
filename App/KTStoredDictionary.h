//
//  KTStoredDictionary.h
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

#import <CoreData/CoreData.h>


@interface KTStoredDictionary : NSManagedObject
{
	// a StoredDictionary is a to-many relationship of entries
	// to either KeyValueAsData or KeyValueAsString objects
	// storage type is determined by asking if value isKindOfClass:NSString
}

/*! returns NSDictionary of entries */
- (NSDictionary *)dictionary;

#pragma mark NSDictionary-like primitives

- (unsigned)count;
- (id)objectForKey:(id)aKey;

- (NSArray *)allKeys;
- (NSEnumerator *)keyEnumerator;

/*! returns an array of the underlying primitive values returned via objectForKey: */
- (NSArray *)allObjects;
- (NSArray *)allValues;


#pragma mark key-value trickery

// these should allow valueForKey: and setValueForKey: to work 
// for entries in the "dictionary" as long as neither key nor entry
// is used as aKey
- (id)valueForUndefinedKey:(NSString *)aKey;

#pragma mark support

- (NSManagedObject *)entryForKey:(NSString *)aKey;

@end

