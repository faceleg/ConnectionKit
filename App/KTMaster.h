//
//  KTMaster.h
//  Sandvox
//
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
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


#import "KSExtensibleManagedObject.h"

#import "KT.h"
#import "SVMediaRecord.h"


@class KTDesign, SVTitleBox, SVRichText, SVLogoImage, KTCodeInjection, SVHTMLContext;


@interface KTMaster : KSExtensibleManagedObject 

#pragma mark Text

@property(nonatomic, retain) SVTitleBox *siteTitle;
@property(nonatomic, retain) SVTitleBox *siteSubtitle;

@property(nonatomic, retain) SVRichText *footer;


#pragma mark Design
- (KTDesign *)design;
- (void)setDesign:(KTDesign *)design;
- (void)setDesignBundleIdentifier:(NSString *)identifier;
- (NSURL *)designDirectoryURL;
- (void)writeCSS:(SVHTMLContext *)context;


#pragma mark Banner

@property(nonatomic, retain) SVMediaRecord *banner;
- (void)setBannerWithContentsOfURL:(NSURL *)URL;   // autodeletes the old one

@property(nonatomic, copy) NSNumber *bannerType;    // treat like BOOL for now

- (void)writeBannerCSS:(SVHTMLContext *)context;
- (void)writeCodeInjectionCSS:(SVHTMLContext *)context;


#pragma mark Logo
@property(nonatomic, retain, readonly) SVLogoImage *logo;


#pragma mark Favicon
@property(nonatomic, readonly) SVMediaRecord *favicon;
@property(nonatomic, copy) NSNumber *faviconType;   // mandatory
@property(nonatomic, retain) SVMediaRecord *faviconMedia;
- (void)setFaviconWithContentsOfURL:(NSURL *)URL;   // autodeletes the old one


#pragma mark Graphical Text
@property(nonatomic, copy) NSNumber *enableImageReplacement;    // BOOL, mandatory
@property(nonatomic, copy) NSNumber *graphicalTitleSize;        // float


#pragma mark Timestamp
@property(nonatomic) NSDateFormatterStyle timestampFormat;
@property(nonatomic, copy) NSNumber *timestampShowTime;


#pragma mark Language & Charset
@property(nonatomic, copy) NSString *language;
@property(nonatomic, copy) NSString *charset;


#pragma mark Comments
@property(nonatomic, assign) NSNumber *commentsProvider;
@property(nonatomic, readonly) NSString *commentsSummary;

// convenciences for examining KTCommentsProvider
- (BOOL)wantsDisqus;
- (BOOL)wantsHaloscan;  // for backward compatibility with KTCommentsProvider enum
- (BOOL)wantsIntenseDebate;
- (BOOL)wantsJSKit;
- (BOOL)wantsFacebookComments;

// extensible properties
- (NSString *)disqusShortName;
- (void)setDisqusShortName:(NSString *)aString;

- (NSString *)JSKitModeratorEmail;
- (void)setJSKitModeratorEmail:(NSString *)aString;

- (NSString *)IntenseDebateAccountID;
- (void)setIntenseDebateAccountID:(NSString *)aString;

- (NSString *)facebookAppID;

#pragma mark Placeholder Image
- (SVMediaRecord *)makePlaceholdImageMediaWithEntityName:(NSString *)entityName;


#pragma mark Site Outline
- (KTCodeInjection *)codeInjection;

@end


@interface KTMaster (PluginAPI)
- (NSDictionary *)imageScalingPropertiesForUse:(NSString *)mediaUse;
@end
