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

#import <Cocoa/Cocoa.h>
#import "KT.h"
#import "SVHTMLTemplateParser.h"
#import "SVExtensibleManagedObject.h"


@class KTDesign, SVTitleBox;
@class KTMediaContainer;


@interface KTMaster : SVExtensibleManagedObject 

#pragma mark Text

@property(nonatomic, retain) SVTitleBox *siteTitle;
- (void)setSiteTitleWithString:(NSString *)title;   // creates Title object if needed

@property(nonatomic, retain) SVTitleBox *siteSubtitle;
- (void)setSiteSubtitleWithString:(NSString *)title;   // creates Title object if needed

@property(nonatomic, retain) SVTitleBox *footer;
- (void)setFooterWithString:(NSString *)text;   // creates Title object if needed
- (NSString *)defaultCopyrightHTML;


#pragma mark Other

- (NSURL *)designDirectoryURL;

- (KTMediaContainer *)bannerImage;
- (void)setBannerImage:(KTMediaContainer *)banner;

- (KTMediaContainer *)logoImage;
- (void)setLogoImage:(KTMediaContainer *)logo;

- (KTMediaContainer *)favicon;
- (void)setFavicon:(KTMediaContainer *)favicon;

#pragma mark Timestamp
@property(nonatomic) NSDateFormatterStyle timestampFormat;
@property(nonatomic, copy) NSNumber *timestampShowTime;

#pragma mark Language
- (NSString *)language;

#pragma mark Placeholder
- (KTMediaContainer *)placeholderImage;

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

@end


@interface KTMaster (PluginAPI)
- (NSDictionary *)imageScalingPropertiesForUse:(NSString *)mediaUse;
@end
