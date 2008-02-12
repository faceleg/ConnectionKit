//
//  KTStoredArray.h
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


@interface KTStoredArray : KTManagedObject
{
	// a StoredArray is a to-many relationship of items
	// to either OrderedValueAsData or OrderedValueAsString objects
	// storage type is determined by asking if value isKindOfClass:NSString
}

+ (id)arrayInManagedObjectContext:(KTManagedObjectContext *)aContext 
					   entityName:(NSString *)anEntityName;

+ (id)arrayWithArray:(id)anArray inManagedObjectContext:(KTManagedObjectContext *)aContext entityName:(NSString *)anEntityName;

#pragma mark NSArray primitives

- (unsigned)count;
- (id)objectAtIndex:(unsigned)index;

#pragma mark NSMutableArray primitives

- (void)addObject:(id)anObject;
- (void)copyObject:(NSManagedObject *)anObject;
- (void)insertObject:(id)anObject atIndex:(unsigned)index;
- (void)removeLastObject;
- (void)removeObjectAtIndex:(unsigned)index;
- (void)replaceObjectAtIndex:(unsigned)index withObject:(id)anObject;

- (void)removeAllObjects;

- (void)addObjectsFromArray:(NSArray *)anArray;  // adds to end of array
- (void)copyObjectsFromArray:(NSArray *)anArray; // maintains same ordering

/*! returns the underlying values of the stored array, according to ordering */
- (NSArray *)allValues;

#pragma mark other array methods

- (NSEnumerator *)objectEnumerator;

@end
