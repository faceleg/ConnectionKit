//
//  ContactElementPlugin.h
//  ContactElement
//
//  Copyright 2006-2009 Karelia Software. All rights reserved.
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

#import "SandvoxPlugin.h"
#import "SandvoxPlugin.h"


@class ContactElementFieldsArrayController, ContactElementField;


@interface ContactElementPlugin : SVElementPlugIn
{
	NSString *_address;
	NSString *_emailLabel;
	NSString *_messageLabel;
	NSString *_nameLabel;
	NSString *_sendButtonTitle;
	NSString *_subjectLabel;
	NSString *_subjectText;
	BOOL _sideLabels;
	int _subjectType;
	NSArray *_fields;
	
	
	@private
	
	ContactElementField *myEmailField;
	
	NSManagedObject *myPluginProperties;
	NSArray	*myFields;
	BOOL	myIsArchivingFields;
}

@property (copy) NSString *address;
@property (copy) NSString *emailLabel;
@property (copy) NSString *messageLabel;
@property (copy) NSString *nameLabel;
@property (copy) NSString *sendButtonTitle;
@property (copy) NSString *subjectLabel;
@property (copy) NSString *subjectText;
@property (assign) BOOL sideLabels;
@property (assign) int subjectType;
@property (copy) NSArray *fields;

- (NSString *)encodedRecipient;
- (NSString *)subjectInputHTML;
- (NSString *)subjectPrompt;
- (NSString *)subjectText;

- (int)subjectType;
- (void)setEncodedRecipient:(NSString *)anEnc;
- (void)setSubjectInputHTML:(NSString *)anHTML;
- (void)setSubjectPrompt:(NSString *)aPrompt;
- (void)setSubjectText:(NSString *)anAddress;
- (void)setSubjectType:(int)aSubjectType;

// New stuff
- (NSArray *)fields;
- (void)setFields:(NSArray *)fields;

@end
