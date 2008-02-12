//
//  NSObject+KTExtensions.h
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


@interface NSObject ( KTExtensions )

// enforcing intentions
+ (void)subclassResponsibility:(SEL)aSelector;
- (void)subclassResponsibility:(SEL)aSelector;
- (void)notImplemented:(SEL)aSelector;
- (void)shouldNotImplement:(SEL)aSelector;

// deprecation
- (void)deprecated:(SEL)aSelector;

// exceptions and errors
- (void)raiseExceptionWithName:(NSString *)name reason:(NSString *)reason userInfo:(NSDictionary *)userInfo;
- (void)raiseExceptionWithName:(NSString *)name reason:(NSString *)reason;
- (void)raiseExceptionWithName:(NSString *)name;

// encodable?
- (BOOL)isFoundationObject;

// managed by a context?
- (BOOL)isManagedObject;

// uses wrappedValueForKey: if possible, else valueForKey:
- (id)wrappedValueForKeyWithFallback:(NSString *)aKey;
- (void)setWrappedValueWithFallback:(id)aValue forKey:(NSString *)aKey;

// KVC & KVO
- (BOOL)boolForKey:(NSString *)aKey;
- (void)setBool:(BOOL)value forKey:(NSString *)aKey;

- (float)floatForKey:(NSString *)aKey;
- (void)setFloat:(float)value forKey:(NSString *)aKey;

- (int)integerForKey:(NSString *)aKey;
- (void)setInteger:(int)value forKey:(NSString *)aKey;

- (void)willChangeValuesForKeys:(NSSet *)keys;
- (void)didChangeValuesForKeys:(NSSet *)keys;

- (void)addObserver:(NSObject *)anObserver forKeyPaths:(NSSet *)keyPaths options:(NSKeyValueObservingOptions)options context:(void *)context;
- (void)removeObserver:(NSObject *)observer forKeyPaths:(NSSet *)keyPaths;

@end
