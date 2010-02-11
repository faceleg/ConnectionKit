//
//  ContactElementInspectorController.m
//  ContactElement
//
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "ContactElementInspectorController.h"
#import <SandvoxPlugin.h>


@implementation ContactElementInspectorController

#pragma mark Init

+ (void)initialize
{
	// Register value transformers
	KSIsEqualValueTransformer *transformer = nil;
	
// TODO: when we can mess with the nib, just take out this transformer binding.
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:             @"email___"];	// HACK -- "DISABLE" THIS SO EMAIL PLACEHOLDER IS ALWAYS ENABLED.  COMPARISON WILL NEVER SUCCEED.
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotEmail"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:@"visitorName"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotName"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:@"subject"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotSubject"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:@"message"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotMessage"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:@"send"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotSend"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
}

#pragma mark View Loading

- (void)loadView
{
    // Make sure the address box comes out right
    [KSEmailAddressComboBox setWillIncludeNames:NO];
    [KSEmailAddressComboBox setWillAddAnonymousEntry:NO];
    
    
    [super loadView];
}

- (void)awakeFromNib
{
	// Set up the box under the table
	[oFieldsTableButtonsBox setDrawsFrame:YES];
	[oFieldsTableButtonsBox setFill:NTBoxBevel];
	[oFieldsTableButtonsBox setBorderMask:(NTBoxLeft | NTBoxRight | NTBoxBottom)];
	[oFieldsTableButtonsBox setFrameColor:[NSColor lightGrayColor]];
	
	// Give the buttons their icons
	[oAddLinkButton setImage:[NSImage addToTableButtonIcon]];
	[oRemoveLinkButton setImage:[NSImage removeFromTableButtonIcon]];
}

@end
