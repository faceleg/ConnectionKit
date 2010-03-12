//
//  SandvoxDesignPlugIn.m
//  SandvoxQuickLook
//
//  Created by Mike on 26/03/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "SandvoxDesignPlugIn.h"


@implementation SandvoxDesignPlugIn

+ (NSString *)pluginSubfolder
{
	return @"Designs";	// subfolder in App Support/APPNAME where this kind of plugin MAY reside.
}

+ (NSString *)applicationPluginPath	// Designs in their own top-level plugin dir
{
	return [[[KSPlugInWrapper applicationBundle] bundlePath] stringByAppendingPathComponent:@"Designs"];
}

/*	Register all known plugin types.
 */
+ (void)load
{
	[KSPlugInWrapper registerPluginClass:[self class] forFileExtension:@"svxDesign"];
	[KSPlugInWrapper registerPluginClass:[KSPlugInWrapper class] forFileExtension:@"svxElement"];
	[KSPlugInWrapper registerPluginClass:[KSPlugInWrapper class] forFileExtension:@"svxIndex"];
}

@end
