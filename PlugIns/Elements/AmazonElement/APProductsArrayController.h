//
//  APProductsArrayController.h
//  Amazon List
//
//  Created by Mike on 02/03/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//	Cocoa bindings don't play well with our product tables since
//	we need one cell to display multiple properties of an object.
//	To handle this, APProductsArrayController forces the appropriate
//	rectangle of a table to redraw whenever a product starts or stops
//	loading.
//	APProductsArrayController handles tooltips for products.
//	Additionally, this class handles opening a product's Amazon page
//	in the user's web browser. 


#import <Cocoa/Cocoa.h>
#import "DNDArrayController.h"

@interface APProductsArrayController : DNDArrayController
{
}

- (IBAction)openProductURL:(id)sender;
@end
