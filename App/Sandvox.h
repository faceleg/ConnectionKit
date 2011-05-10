//
//  Sandvox.h
//  Sandvox
//
//  Copyright 2004-2011 Karelia Software. All rights reserved.
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

//  Sandvox.h is a convenience header that imports all "public" headers in Sandvox
//  Each header is well commented as to its functionality. Further information can be found online at 
//  http://www.karelia.com/sandvox/help/z/Sandvox_Developers_Guide.html


// Core
#import "SVPlugIn.h"
#import "SVInspectorViewController.h"
#import "SVPlugInContext.h"

// Indexes
#import "SVIndexPlugIn.h"
#import "SVIndexInspectorViewController.h"

// Page composition
#import "SVPageProtocol.h"

// Cocoa extensions
#import "NSBundle+Sandvox.h"
#import "NSURL+Sandvox.h"
#import "SVLabel.h"
#import "SVFieldFormatter.h"
#import "SVPasteboardItem.h"
#import "SVURLFormatter.h"

// Localization
//  requires adding a Run Script Build Phase of
//  cd ${SRCROOT}; genstrings -littleEndian -q -u -s SVLocalizedString -o en.lproj *.m
#ifndef SVLocalizedString(key,comment)
    #define SVLocalizedString(key,comment) [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:nil]
#endif

