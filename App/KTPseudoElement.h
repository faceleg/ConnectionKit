//
//  KTPseudoElement.h
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

// subclass to put an inspector around a particular DOM element
// for example, KTInlineImageElement wraps an inspector around <img> tags

// you can send setValue:forKey: to this class and it will store it in
// properties via setValue:forUndefinedKey:

#import <Cocoa/Cocoa.h>

#import "KTAbstractElement.h"				// our container will be one of these


@class DOMNode;


@interface KTPseudoElement : NSObject
{
	DOMNode				*myDOMNode;
	KTAbstractElement	*myContainer;
	
	NSMutableDictionary	*myPrimitiveValues;
	BOOL				myAutomaticUndoIsEnabled;
}

- (id)initWithDOMNode:(DOMNode *)node container:(KTAbstractElement *)container;

// NSManagedObject clones
- (id)primitiveValueForKey:(NSString *)key;
- (void)setPrimitiveValue:(id)value forKey:(NSString *)key;

- (BOOL)automaticUndoIsEnabled;
- (void)setAutomaticUndoIsEnabled:(BOOL)flag;

// conform to KTInspectorPlugin protocol
- (NSString *)uniqueID;
- (id)inspectorObject;
- (NSBundle *)inspectorNibBundle;
- (NSString *)inspectorNibName;
- (id)inspectorNibOwner;

// Accessors
- (DOMNode *)DOMNode;
- (KTAbstractElement *)container;

@end
