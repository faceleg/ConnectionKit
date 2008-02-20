//
//  KTAppPlugin.h
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "QuickLookSandvoxPlugin.h"


@interface KTAppPlugin : QuickLookSandvoxPlugin
{
}

+ (Class)registeredPluginClassForFileExtension:(NSString *)extension;
+ (void)registerPluginClass:(Class)pluginClass forFileExtension:(NSString *)extension;

- (NSString *)pluginType;
- (NSString *)version;
- (NSString *)identifier;
- (NSString *)minimumAppVersion;

- (id)pluginPropertyForKey:(NSString *)key;
- (id)defaultPluginPropertyForKey:(NSString *)key;

@end
