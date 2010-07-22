//  DMLocalizedNibBundle.m
//
//  Created by William Jon Shipley on 2/13/05.
//  Copyright © 2005-2009 Golden % Braeburn, LLC. All rights reserved except as below:
//  This code is provided as-is, with no warranties or anything. You may use it in your projects as you wish, but you must leave this comment block (credits and copyright) intact. That's the only restriction -- Golden % Braeburn otherwise grants you a fully-paid, worldwide, transferrable license to use this code as you see fit, including but not limited to making derivative works.
//
//
// Modified by Dan Wood of Karelia Software
//
// Some of this is inspired and modified by GTMUILocalizer from Google Toolbox http://google-toolbox-for-mac.googlecode.com
// (BSD license)

// KNOWN LIMITATIONS
//
// NOTE: NSToolbar localization support is limited to only working on the
// default items in the toolbar. We cannot localize items that are on of the
// customization palette but not in the default items because there is not an
// API for NSToolbar to get all possible items. You are responsible for
// localizing all non-default toolbar items by hand.
//
// Due to technical limitations, accessibility description cannot be localized.
// See http://lists.apple.com/archives/Accessibility-dev/2009/Dec/msg00004.html
// and http://openradar.appspot.com/7496255 for more information.



#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

@interface NSBundle (DMLocalizedNibBundle)
+ (BOOL)deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone;
+ (BOOL)_deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone bundle:(NSBundle *)aBundle;
@end


// Try to swizzle in -[NSViewController loadView]

@interface NSViewController (DMLocalizedNibBundle)
- (void)deliciousLocalizingLoadView;
@end

@implementation NSViewController (DMLocalizedNibBundle)

+ (void)load;
{
    NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
    if (
		
		([NSUserName() isEqualToString:@"dwood"]) &&
		
		self == [NSViewController class]) {
		NSLog(@"Switching in NSViewController Localizer!");
        method_exchangeImplementations(class_getInstanceMethod(self, @selector(loadView)), class_getInstanceMethod(self, @selector(deliciousLocalizingLoadView)));
    }
    [autoreleasePool release];
}


- (void)deliciousLocalizingLoadView
{
	NSString		*nibName	= [self nibName];
	NSBundle		*nibBundle	= [self nibBundle];		
	NSLog(@"%s %@ %@",__FUNCTION__, nibName, nibBundle);
									if(!nibBundle) nibBundle = [NSBundle mainBundle];
	NSString		*nibPath	= [nibBundle pathForResource:nibName ofType:@"nib"];
	NSDictionary	*context	= [NSDictionary dictionaryWithObjectsAndKeys:self, NSNibOwner, nil];
	
	BOOL loaded = [NSBundle _deliciousLocalizingLoadNibFile:nibPath externalNameTable:context withZone:nil bundle:nibBundle];	// call through to support method
	if (!loaded)
	{
		[NSBundle deliciousLocalizingLoadNibFile:nibPath externalNameTable:context withZone:nil];	// use old-fashioned way
	}
}

@end





@interface NSBundle ()
+ (void)				  _localizeStringsInObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
+ (NSString *)	 _localizedStringForString:(NSString *)string bundle:(NSBundle *)bundle table:(NSString *)table;
// localize particular attributes in objects
+ (void)					_localizeTitleOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
+ (void)		   _localizeAlternateTitleOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
+ (void)			  _localizeStringValueOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
+ (void)		_localizePlaceholderStringOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
+ (void)				  _localizeToolTipOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
+ (void)				    _localizeLabelOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
+ (void)			 _localizePaletteLabelOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
@end


@implementation NSBundle (DMLocalizedNibBundle)

#pragma mark NSObject

+ (void)load;
{
    NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
    if (
		
		([NSUserName() isEqualToString:@"dwood"]) &&
		
		self == [NSBundle class]) {
		NSLog(@"Switching in NSBundle localizer. W00T!");
        method_exchangeImplementations(class_getClassMethod(self, @selector(loadNibFile:externalNameTable:withZone:)), class_getClassMethod(self, @selector(deliciousLocalizingLoadNibFile:externalNameTable:withZone:)));
    }
    [autoreleasePool release];
}


#pragma mark API

// Method that gets swapped
+ (BOOL)deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone;
{
	NSLog(@"%s %@",__FUNCTION__, fileName);
	BOOL result = [self _deliciousLocalizingLoadNibFile:fileName externalNameTable:context withZone:zone bundle:[NSBundle mainBundle]];
	if (!result)
	{
		// try original version
		result = [self deliciousLocalizingLoadNibFile:fileName externalNameTable:context withZone:zone];
	}
	return result;
}

// Internal method, which gets an extra parameter for bundle
+ (BOOL)_deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone bundle:(NSBundle *)aBundle;
{
	NSLog(@"%s %@",__FUNCTION__, fileName);
	
	// Note: What about loading not from the main bundle? Can I try to load from where the nib file came from?
	
    NSString *localizedStringsTableName = [[fileName lastPathComponent] stringByDeletingPathExtension];
    NSString *localizedStringsTablePath = [[NSBundle mainBundle] pathForResource:localizedStringsTableName ofType:@"strings"];
    if (
		localizedStringsTablePath
		&& ![[[localizedStringsTablePath stringByDeletingLastPathComponent] lastPathComponent] isEqualToString:@"English.lproj"]
		&& ![[[localizedStringsTablePath stringByDeletingLastPathComponent] lastPathComponent] isEqualToString:@"en.lproj"]
		)
	{
        
        NSNib *nib = [[NSNib alloc] initWithContentsOfURL:[NSURL fileURLWithPath:fileName]];
        NSMutableArray *topLevelObjectsArray = [context objectForKey:NSNibTopLevelObjects];
        if (!topLevelObjectsArray) {
            topLevelObjectsArray = [NSMutableArray array];
            context = [NSMutableDictionary dictionaryWithDictionary:context];
            [(NSMutableDictionary *)context setObject:topLevelObjectsArray forKey:NSNibTopLevelObjects];
        }
        BOOL success = [nib instantiateNibWithExternalNameTable:context];
		
        [self _localizeStringsInObject:topLevelObjectsArray bundle:aBundle table:localizedStringsTableName];		// BUNDLE?
        
        [nib release];
        return success;
        
    } else {
		
        if (nil == localizedStringsTablePath)
		{
			NSLog(@"Not running through localizer because localizedStringsTablePath == nil");
		}
		else
		{
			NSLog(@"Not running through localizer because containing dir is not English: %@", [[localizedStringsTablePath stringByDeletingLastPathComponent] lastPathComponent]);
		}
		
		return NO;		// not successful
    }
}



#pragma mark Private API


/*
 
 Aspects of a nib still to do:
	NSTableView
	AXDescription and AXRole
	
 Others?
 
 Next up: stretching items....
 
 
 */

+ (void)_localizeAccessibility:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
{
	NSArray *supportedAttrs = [object accessibilityAttributeNames];
	if ([supportedAttrs containsObject:NSAccessibilityHelpAttribute]) {
		NSString *accessibilityHelp
		= [object accessibilityAttributeValue:NSAccessibilityHelpAttribute];
		if (accessibilityHelp) {
			NSString *localizedAccessibilityHelp
			= [self _localizedStringForString:accessibilityHelp bundle:bundle table:table];
			if (localizedAccessibilityHelp) {
				
				if ([object accessibilityIsAttributeSettable:NSAccessibilityHelpAttribute])
				{
					NSLog(@"ACCESSIBILITY: %@ %@", localizedAccessibilityHelp, localizedAccessibilityHelp);
					[object accessibilitySetValue:localizedAccessibilityHelp
									 forAttribute:NSAccessibilityHelpAttribute];
				}
				else
				{
					NSLog(@"DISALLOWED ACCESSIBILITY: %@ %@", localizedAccessibilityHelp, localizedAccessibilityHelp);

				}
			}
		}
	}
}


//
// NOT SURE:
// Should we localize NSWindowController's window and NSViewController's view? Probably not; they would be top-level objects in nib.
// Or NSApplication's main menu? Probably same thing.


+ (void)_localizeStringsInObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
{
	// NSArray ... this is not directly in the nib, but for when we recurse.
	
    if ([object isKindOfClass:[NSArray class]]) {
        NSArray *array = object;
        
        for (id nibItem in array)
            [self _localizeStringsInObject:nibItem bundle:bundle table:table];
	
	// NSCell & subclasses
		
    } else if ([object isKindOfClass:[NSCell class]]) {
        NSCell *cell = object;
        
        if ([cell isKindOfClass:[NSActionCell class]]) {
            NSActionCell *actionCell = (NSActionCell *)cell;
            
            if ([actionCell isKindOfClass:[NSButtonCell class]]) {
                NSButtonCell *buttonCell = (NSButtonCell *)actionCell;
                if ([buttonCell imagePosition] != NSImageOnly) {
                    [self _localizeTitleOfObject:buttonCell bundle:bundle table:table];
                    [self _localizeStringValueOfObject:buttonCell bundle:bundle table:table];
                    [self _localizeAlternateTitleOfObject:buttonCell bundle:bundle table:table];
                }
                
            } else if ([actionCell isKindOfClass:[NSTextFieldCell class]]) {
                NSTextFieldCell *textFieldCell = (NSTextFieldCell *)actionCell;
                // Following line is redundant with other code, localizes twice.
                // [self _localizeTitleOfObject:textFieldCell bundle:bundle table:table];
                [self _localizeStringValueOfObject:textFieldCell bundle:bundle table:table];
                [self _localizePlaceholderStringOfObject:textFieldCell bundle:bundle table:table];
                
            } else if ([actionCell type] == NSTextCellType) {
                [self _localizeTitleOfObject:actionCell bundle:bundle table:table];
                [self _localizeStringValueOfObject:actionCell bundle:bundle table:table];
            }
        }
        
	// NSToolbar
		
    } else if ([object isKindOfClass:[NSToolbar class]]) {
        NSToolbar *toolbar = object;
		NSArray *items = [toolbar items];
		for (NSToolbarItem *item in items)
		{
			[self _localizeLabelOfObject:item bundle:bundle table:table];
			[self _localizePaletteLabelOfObject:item bundle:bundle table:table];
			[self _localizeToolTipOfObject:item bundle:bundle table:table];
		}
		
	// NSTableView
	} else if ([object isKindOfClass:[NSToolbar class]]) {
		NSTableView *tableView = (NSTableView *)object;
		NSArray *columns = [tableView tableColumns];
		for (NSTableColumn *column in columns)
		{
			[self _localizeStringValueOfObject:[column headerCell] bundle:bundle table:table];
		}
		
	// NSMenu
		
    } else if ([object isKindOfClass:[NSMenu class]]) {
        NSMenu *menu = object;
        [self _localizeTitleOfObject:menu bundle:bundle table:table];
        
        [self _localizeStringsInObject:[menu itemArray] bundle:bundle table:table];
        
	// NSMenuItem
		
    } else if ([object isKindOfClass:[NSMenuItem class]]) {
        NSMenuItem *menuItem = object;
        [self _localizeTitleOfObject:menuItem bundle:bundle table:table];
        
        [self _localizeStringsInObject:[menuItem submenu] bundle:bundle table:table];
        
	// NSView + subclasses
				
    } else if ([object isKindOfClass:[NSView class]]) {
        NSView *view = object;
        [self _localizeToolTipOfObject:view bundle:bundle table:table];
        
		[self _localizeAccessibility:view bundle:bundle table:table];

		[self _localizeStringsInObject:[view menu] bundle:bundle table:table];
		
		// NSBox
		
        if ([view isKindOfClass:[NSBox class]]) {
            NSBox *box = (NSBox *)view;
            [self _localizeTitleOfObject:box bundle:bundle table:table];
           
		// NSTabView
			
        } else if ([view isKindOfClass:[NSTabView class]]) {
            NSTabView *tabView = (NSTabView *)view;
			NSArray *tabViewItems = [tabView tabViewItems];
		
			for (NSTabViewItem *item in tabViewItems)
			{
				[self _localizeLabelOfObject:item bundle:bundle table:table];
				
				NSView *viewToLocalize = [item view];
				if (![[view subviews] containsObject:viewToLocalize])	// don't localize one that is current subview
				{
					[self _localizeStringsInObject:viewToLocalize bundle:bundle table:table];
				}
			}
		
		// NSControl + subclasses
			
        } else if ([view isKindOfClass:[NSControl class]]) {
            NSControl *control = (NSControl *)view;
            
			[self _localizeAccessibility:[control cell] bundle:bundle table:table];

			
			// NSButton
			
            if ([view isKindOfClass:[NSButton class]]) {
                NSButton *button = (NSButton *)control;
                
                if ([button isKindOfClass:[NSPopUpButton class]]) {
                    NSPopUpButton *popUpButton = (NSPopUpButton *)button;
                    NSMenu *menu = [popUpButton menu];
                    
                    [self _localizeStringsInObject:[menu itemArray] bundle:bundle table:table];
                } else
                    [self _localizeStringsInObject:[button cell] bundle:bundle table:table];
                
			
			// NSMatrix
				
            } else if ([view isKindOfClass:[NSMatrix class]]) {
                NSMatrix *matrix = (NSMatrix *)control;
                
                NSArray *cells = [matrix cells];
                [self _localizeStringsInObject:cells bundle:bundle table:table];
                
                for (NSCell *cell in cells) {
                    
                    NSString *localizedCellToolTip = [self _localizedStringForString:[matrix toolTipForCell:cell] bundle:bundle table:table];
                    if (localizedCellToolTip)
                        [matrix setToolTip:localizedCellToolTip forCell:cell];
                }
              
			// NSSegmentedControl
				
            } else if ([view isKindOfClass:[NSSegmentedControl class]]) {
                NSSegmentedControl *segmentedControl = (NSSegmentedControl *)control;
                
                NSUInteger segmentIndex, segmentCount = [segmentedControl segmentCount];
                for (segmentIndex = 0; segmentIndex < segmentCount; segmentIndex++) {
                    NSString *localizedSegmentLabel = [self _localizedStringForString:[segmentedControl labelForSegment:segmentIndex] bundle:bundle table:table];
                    if (localizedSegmentLabel)
                        [segmentedControl setLabel:localizedSegmentLabel forSegment:segmentIndex];
                    
                    [self _localizeStringsInObject:[segmentedControl menuForSegment:segmentIndex] bundle:bundle table:table];
                }
             
			// OTHER
				
            } else
                [self _localizeStringsInObject:[control cell] bundle:bundle table:table];
            
        }
        
		// Then localize this view's subviews
		
        [self _localizeStringsInObject:[view subviews] bundle:bundle table:table];
       
	// NSWindow
		
    } else if ([object isKindOfClass:[NSWindow class]]) {
        NSWindow *window = object;
        [self _localizeTitleOfObject:window bundle:bundle table:table];
        
        [self _localizeStringsInObject:[window contentView] bundle:bundle table:table];
		[self _localizeStringsInObject:[window toolbar] bundle:bundle table:table];

    }
	
	// Finally, bindings.  Basically lifted from the Google Toolkit.
	NSArray *exposedBindings = [object exposedBindings];
	if (exposedBindings) {
		NSString *optionsToLocalize[] = {
			NSDisplayNameBindingOption,
			NSDisplayPatternBindingOption,
			NSMultipleValuesPlaceholderBindingOption,
			NSNoSelectionPlaceholderBindingOption,
			NSNotApplicablePlaceholderBindingOption,
			NSNullPlaceholderBindingOption,
		};
		for (NSString *exposedBinding in exposedBindings)
		{
			NSDictionary *bindingInfo = [object infoForBinding:exposedBinding];
			if (bindingInfo) {
				id observedObject = [bindingInfo objectForKey:NSObservedObjectKey];
				NSString *path = [bindingInfo objectForKey:NSObservedKeyPathKey];
				NSDictionary *options = [bindingInfo objectForKey:NSOptionsKey];
				if (observedObject && path && options) {
					NSMutableDictionary *newOptions 
					= [NSMutableDictionary dictionaryWithDictionary:options];
					BOOL valueChanged = NO;
					for (size_t i = 0; 
						 i < sizeof(optionsToLocalize) / sizeof(optionsToLocalize[0]);
						 ++i) {
						NSString *key = optionsToLocalize[i];
						NSString *value = [newOptions objectForKey:key];
						if ([value isKindOfClass:[NSString class]]) {
							NSString *localizedValue = [self _localizedStringForString:value bundle:bundle table:table];
							if (localizedValue) {
								valueChanged = YES;
								[newOptions setObject:localizedValue forKey:key];
							}
						}
					}
					if (valueChanged) {
						// Only unbind and rebind if there is a change.
						[object unbind:exposedBinding];
						[object bind:exposedBinding 
							toObject:observedObject 
						 withKeyPath:path 
							 options:newOptions];
					}
				}
			}
		}
	}
	
	
}



+ (NSString *)_localizedStringForString:(NSString *)string bundle:(NSBundle *)bundle table:(NSString *)table;
{
    if (![string length])
        return nil;
    
	if ([string hasPrefix:@"["])
	{
		NSLog(@"??? Double-translation of %@", string);
	}
    static NSString *defaultValue = @"I AM THE DEFAULT VALUE";
    NSString *localizedString = [bundle localizedStringForKey:string value:defaultValue table:table];
    if (localizedString != defaultValue) {
        return [NSString stringWithFormat:@"[_%@_]", localizedString];
    } else { 
#ifdef DEBUG
        NSLog(@"        Can't find translation for string %@", string);
        return [NSString stringWithFormat:@"[%@]", string];
#else
        return string;
#endif
    }
}


#define DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(blahName, capitalizedBlahName) \
+ (void)_localize ##capitalizedBlahName ##OfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table; \
{ \
NSString *localizedBlah = [self _localizedStringForString:[object blahName] bundle:bundle table:table]; \
if (localizedBlah) \
[object set ##capitalizedBlahName:localizedBlah]; \
}

DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(title, Title)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(alternateTitle, AlternateTitle)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(stringValue, StringValue)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(placeholderString, PlaceholderString)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(toolTip, ToolTip)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(label, Label)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(paletteLabel, PaletteLabel)

@end
