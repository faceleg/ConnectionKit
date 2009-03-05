//
//  KTAbstractElement+Inspector.h
//  Marvel
//
//  Created by Mike on 20/10/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTAbstractElement.h"

#import "KTPluginInspectorViewsManager.h"


@interface KTAbstractElement (Internal)

- (KTElementPlugin *)plugin;
//- (KTDocument *)document;
- (KTPage *)page;	// enclosing page (self if this is a page)
- (BOOL)allowIntroduction;

// Media
- (KTMediaManager *)mediaManager;
- (NSSet *)requiredMediaIdentifiers;

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
- (NSString *)commentsTemplate;

- (NSString *)templateHTML;
- (NSString *)cssClassName;

@end


@interface KTAbstractElement (Inspector) <KTInspectorPlugin>
 
// Inspector
- (id)inspectorObject;
- (NSBundle *)inspectorNibBundle;
- (NSString *)inspectorNibName;
- (id)inspectorNibOwner;

@end
