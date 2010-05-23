//
//  KTMaster.h
//  Sandvox
//
//  Copyright 2007-2009 Karelia Software. All rights reserved.
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


#import "SVExtensibleManagedObject.h"

#import "KT.h"
#import "SVMediaRecord.h"


@class KTDesign, SVTitleBox, SVLogoImage, KTCodeInjection;


@interface KTMaster : SVExtensibleManagedObject 

#pragma mark Text

@property(nonatomic, retain) SVTitleBox *siteTitle;
@property(nonatomic, retain) SVTitleBox *siteSubtitle;

@property(nonatomic, retain) SVTitleBox *footer;
- (NSString *)defaultCopyrightHTML;


#pragma mark Other

- (KTDesign *)design;
- (void)setDesign:(KTDesign *)design;
- (void)setDesignBundleIdentifier:(NSString *)identifier;
- (NSURL *)designDirectoryURL;


#pragma mark Banner

@property(nonatomic, retain) SVMediaRecord *banner;
- (void)setBannerWithContentsOfURL:(NSURL *)URL;   // autodeletes the old one

@property(nonatomic, copy) NSNumber *bannerType;    // treat like BOOL for now

- (void)writeBannerCSS;


#pragma mark Logo
@property(nonatomic, retain, readonly) SVLogoImage *logo;


#pragma mark Favicon
@property(nonatomic, readonly) id <IMBImageItem> favicon;
@property(nonatomic, copy) NSNumber *faviconType;   // mandatory
@property(nonatomic, retain) SVMediaRecord *faviconMedia;
- (void)setFaviconWithContentsOfURL:(NSURL *)URL;   // autodeletes the old one


#pragma mark Graphical Text
@property(nonatomic, copy) NSNumber *enableImageReplacement;    // BOOL, mandatory
@property(nonatomic, copy) NSNumber *graphicalTitleSize;        // float


#pragma mark Timestamp
@property(nonatomic) NSDateFormatterStyle timestampFormat;
@property(nonatomic, copy) NSNumber *timestampShowTime;


#pragma mark Language
@property(nonatomic, copy) NSString *language;


#pragma mark Comments
- (KTCommentsProvider)commentsProvider;
- (void)setCommentsProvider:(KTCommentsProvider)aKTCommentsProvider;

- (BOOL)wantsDisqus;
- (void)setWantsDisqus:(BOOL)aBool;

- (NSString *)disqusShortName;
- (void)setDisqusShortName:(NSString *)aString;


- (BOOL)wantsHaloscan;
- (void)setWantsHaloscan:(BOOL)aBool;

- (BOOL)wantsJSKit;
- (void)setWantsJSKit:(BOOL)aBool;

- (NSString *)JSKitModeratorEmail;
- (void)setJSKitModeratorEmail:(NSString *)aString;


#pragma mark Site Outline
- (KTCodeInjection *)codeInjection;

@end


@interface KTMaster (PluginAPI)
- (NSDictionary *)imageScalingPropertiesForUse:(NSString *)mediaUse;
@end
