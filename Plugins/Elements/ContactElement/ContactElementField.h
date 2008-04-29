//
//  ContactElementField.h
//  ContactElement
//
//  Created by Mike on 11/05/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


typedef enum
{
	ContactElementTextFieldField = 1,
	ContactElementTextAreaField = 2,
	ContactElementCheckBoxField = 3,
	ContactElementPopupButtonField = 4,
	ContactElementRadioButtonsField = 5,
	ContactElementSubmitButton = 6,
	ContactElementHiddenField = 0,
} ContactElementFieldType;


@class ContactElementDelegate;


@interface ContactElementField : NSObject <NSCopying>
{
	ContactElementDelegate	*myOwner;
	
	NSString				*myIdentifier;
	ContactElementFieldType	myType;
	NSString				*myLabel;
	NSString				*myDefaultString;
	NSString				*myCheckBoxLabel;
	BOOL					myCheckBoxIsSelected;
	NSArray					*myVisitorChoices;
}

// Init
- (id)initWithIdentifier:(NSString *)identifier;
- (id)initWithDictionary:(NSDictionary *)dictionary;

// Owner
- (ContactElementDelegate *)owner;
- (void)setOwner:(ContactElementDelegate *)owner;

// Accessors
- (NSString *)identifier;

- (ContactElementFieldType)type;
- (void)setType:(ContactElementFieldType)type;

- (NSString *)label;
- (void)setLabel:(NSString *)label;
- (NSString *)labelWithLocalizedColonSuffix;

- (NSString *)defaultString;
- (void)setDefaultString:(NSString *)defaultString;

- (NSString *)checkBoxLabel;
- (void)setCheckBoxLabel:(NSString *)label;

- (BOOL)checkBoxIsSelected;
- (void)setCheckBoxIsSelected:(BOOL)selected;

- (NSArray *)visitorChoices;
- (void)setVisitorChoices:(NSArray *)choices;

// UI
- (BOOL)shouldDrawLockIcon;

// Storage
- (NSDictionary *)dictionaryRepresentation;

// HTML
- (NSString *)inputName;

@end
