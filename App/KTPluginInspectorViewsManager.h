//
//  KTPluginInspectorViewsManager.h
//  Marvel
//
//  Created by Mike on 28/08/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol KTInspectorPlugin <NSObject>
- (id)inspectorObject;	// The object to connect the objectController to (generally self)
- (NSBundle *)inspectorNibBundle;
- (NSString *)inspectorNibName;
- (id)inspectorNibOwner;	// The nib's "File's Owner" object (generally self)
@end



@interface KTPluginInspectorViewsManager : NSObject
{
	@private
	NSMutableDictionary	*myPluginTopLevelObjects;
	NSMutableDictionary	*myPluginInspectorViews;
	NSMutableDictionary	*myPluginControllers;
}

- (NSView *)inspectorViewForPlugin:(id <KTInspectorPlugin>)plugin;
- (void)removeInspectorViewForPlugin:(id <KTInspectorPlugin>)plugin;
- (void)removeAllPluginInspectorViews;

@end
