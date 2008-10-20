//
//  KTAbstractElement+Inspector.h
//  Marvel
//
//  Created by Mike on 20/10/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTAbstractElement.h"

#import "KTPluginInspectorViewsManager.h"


@interface KTAbstractElement (Inspector) <KTInspectorPlugin>
 
// Inspector
- (id)inspectorObject;
- (NSBundle *)inspectorNibBundle;
- (NSString *)inspectorNibName;
- (id)inspectorNibOwner;

@end
