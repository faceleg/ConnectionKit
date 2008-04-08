//
//  KTAbstractElement.h
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
#import "KTPluginInspectorViewsManager.h"


#import <WebKit/WebKit.h>


@class KTDocument, KTMediaManager, KTElementPlugin, KTPage;


@interface KTAbstractElement : KTManagedObject <KTInspectorPlugin>
{
    // optional delegate
	id					myDelegate;
}

#pragma mark awake

// Plugin awake
- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject; // we want to be able to pass a flag here for special circumstances
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary;

// Delegate
- (id)delegate;
- (void)setDelegate:(id)anObject;
- (KTElementPlugin *)plugin;


// Accessors
- (NSString *)uniqueID; // for convenience
- (KTDocument *)document;
- (NSUndoManager *)undoManager;
- (KTPage *)root;
- (KTPage *)page;	// enclosing page (self if this is a page)
- (BOOL)allowIntroduction;

// Media
- (KTMediaManager *)mediaManager;
- (NSSet *)requiredMediaIdentifiers;

// Inspector
- (id)inspectorObject;
- (NSBundle *)inspectorNibBundle;
- (NSString *)inspectorNibName;
- (id)inspectorNibOwner;

// Perform Selector
- (void)makeSelfOrDelegatePerformSelector:(SEL)selector
							   withObject:(void *)anObject
								 withPage:(KTPage *)page
								recursive:(BOOL)recursive;

- (void)addResourcesToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage;
- (void)addCSSFilePathToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage;
- (NSString *)spotlightHTML;

// HTML
- (NSString *)elementTemplate;	// instance method too for key paths to work in tiger

- (NSString *)templateHTML;
- (NSString *)cssClassName;

@end


@interface KTAbstractElement (Pasteboard)
+ (NSSet *)keysToIgnoreForPasteboardRepresentation;
- (id <NSCoding>)pasteboardRepresentation;
- (id <NSCoding>)IDOnlyPasteboardRepresentation;
@end


@interface NSObject (KTAbstractPluginDelegate)
- (void)plugin:(KTAbstractElement *)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue;

- (BOOL)plugin:(KTAbstractElement *)plugin
	shouldInsertNode:(DOMNode *)node
  intoTextForKeyPath:(NSString *)keyPath
		 givenAction:(WebViewInsertAction)action;

@end


@protocol KTExtensiblePluginPropertiesArchiving
+ (id)objectWithArchivedIdentifier:(NSString *)identifier inDocument:(KTDocument *)document;
- (NSString *)archiveIdentifier;
@end
