//
//  ContactElementFieldsArrayController.h
//  ContactElement
//
//  Created by Mike on 12/05/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <Sandvox.h>
#import <DNDArrayController.h>


@interface ContactElementFieldsArrayController : DNDArrayController
{
	IBOutlet KTAbstractPluginDelegate *pluginDelegate;
}

@end
