//
//  KTPopUpButton.h
//  Marvel
//
//  Created by Mike on 24/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTPopUpButton : NSPopUpButton
{
	NSArray *myContent;
	NSArray *myContentValues;
	id		mySelectedObject;
	
	NSString *myMenuTitle;
	NSString *myDefaultValue;
}

- (NSArray *)content;
- (void)setContent:(NSArray *)content;
- (NSArray *)contentValues;
- (void)setContentValues:(NSArray *)values;
- (id)selectedObject;
- (void)setSelectedObject:(id)anObject;

- (NSString *)menuTitle;
- (void)setMenuTitle:(NSString *)title;
- (NSString *)defaultValue;
- (void)setDefaultValue:(NSString *)defaultValue;

@end
