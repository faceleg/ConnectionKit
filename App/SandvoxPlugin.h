//
//  Sandvox.h
//  Sandvox
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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

// SandvoxPlugin.h is a convenience header that imports all "public" headers in Sandvox


// Debugging
#import "assertions.h"  // TODO: private
#import "Macros.h"      // TODO: private

// Core
#import "SVPlugIn.h"
#import "SVPlugInContext.h"

// Page composition
#import "SVPageProtocol.h"

// Indexes
#import "SVIndexPlugIn.h"
#import "SVIndexInspectorViewController.h"

// Publishing

// Foundation/AppKit subclasses
#import "KSEmailAddressComboBox.h"          // TODO: private
#import "KSLabel.h"                         // TODO: replace with SVLabel
#import "KSPlaceholderTableView.h"          // TODO: private
#import "KSTrimFirstLineFormatter.h"        // TODO: Rename as SV…
#import "KSVerticallyAlignedTextCell.h"     // TODO: private
#import "SVPasteboardItem.h"
#import "SVWebLocation.h"
#import "SVURLFormatter.h"

// Foundation extensions
#import "NSBundle+Karelia.h"  // TODO: Publish -localizedStringForString:language:fallback: only
#import "NSData+Karelia.h"      // TODO: private
#import "NSURL+Sandvox.h"

// AppKit extensions
#import "NSColor+Karelia.h"     // TODO: project
#import "NSImage+Karelia.h"     // TODO: private

// Value Transformers
#import "KSContainsObjectValueTransformer.h"    // TODO: project
#import "KSIsEqualValueTransformer.h"           // TODO: private

// Third Party
#import "DNDArrayController.h"  // TODO: private
