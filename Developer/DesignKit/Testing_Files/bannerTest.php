<?php    

class plistParser extends XMLReader
{
    public function parse($file) {
        trigger_error(
            'plistParser::parse() is deprecated, please use plistParser::parseFile()',
            E_USER_NOTICE
        );

        return $this->parseFile($file);
    }
    
    public function parseFile($file) {
		if(basename($file) == $file) {
			throw new Exception("Non-relative file path expected", 1);
		}
		$this->open("file://" . $file);
		return $this->process();
	}

    public function parseString($string) {
        $this->XML($string);
        return $this->process();
    }

    private function process() {
		// plist's always start with a doctype, use it as a validity check
		$this->read();
		if($this->nodeType !== XMLReader::DOC_TYPE || $this->name !== "plist") {
			throw new Exception(sprintf("Error parsing plist. nodeType: %d -- Name: %s", $this->nodeType, $this->name), 2);
		}
		
		// as one additional check, the first element node is always a plist
		if(!$this->next("plist") || $this->nodeType !== XMLReader::ELEMENT || $this->name !== "plist") {
			throw new Exception(sprintf("Error parsing plist. nodeType: %d -- Name: %s", $this->nodeType, $this->name), 3);
		}
		
		$plist = array();	
		while($this->read()) {
			if($this->nodeType == XMLReader::ELEMENT) {
				$plist[] = $this->parse_node();
			}
		}
		if(count($plist) == 1 && $plist[0]) {
			// Most plists have a dict as their outer most tag
			// So instead of returning an array with only one element
			// return the contents of the dict instead
			return $plist[0];
		} else {
			return $plist;
		}
    }

	private function parse_node() {
		// If not an element, nothing for us to do
		if($this->nodeType !== XMLReader::ELEMENT) return;
		
		switch($this->name) {
			case 'data': 
				return base64_decode($this->getNodeText());
				break;
			case 'real':
				return floatval($this->getNodeText());
				break;
			case 'string':
				return $this->getNodeText();
				break;
			case 'integer':
				return intval($this->getNodeText());
				break;
			case 'date':
				return $this->getNodeText();
				break;
			case 'true':
				return true;
				break;
			case 'false':
				return false;
				break;
			case 'array':
				return $this->parse_array();
				break;
			case 'dict':
				return $this->parse_dict();
				break;
			default:
				// per DTD, the above is the only valid types
				throw new Exception(sprintf("Not a valid plist. %s is not a valid type", $this->name), 4);
		}			
	}
	
	private function parse_dict() {
		$array = array();
		$this->nextOfType(XMLReader::ELEMENT);
		do {
			if($this->nodeType !== XMLReader::ELEMENT || $this->name !== "key") {
				// If we aren't on a key, then jump to the next key
				// per DTD, dicts have to have <key><somevalue> and nothing else
				if(!$this->next("key")) {
					// no more keys left so per DTD we are done with this dict
					return $array;
				}
			}
			$key = $this->getNodeText();
			$this->nextOfType(XMLReader::ELEMENT);
			$array[$key] = $this->parse_node();
			$this->nextOfType(XMLReader::ELEMENT, XMLReader::END_ELEMENT);
		} while($this->nodeType && !$this->isNodeOfTypeName(XMLReader::END_ELEMENT, "dict"));
		return $array;
	}
	
	private function parse_array() {
		$array = array();
        $this->nextOfType(XMLReader::ELEMENT);
		do {
			$array[] = $this->parse_node();
			// skip over any whitespace
			$this->nextOfType(XMLReader::ELEMENT, XMLReader::END_ELEMENT);
		} while($this->nodeType && !$this->isNodeOfTypeName(XMLReader::END_ELEMENT, "array"));
		return $array;
	}
	
	private function getNodeText() {
		$string = $this->readString();
		// now gobble up everything up to the closing tag
		$this->nextOfType(XMLReader::END_ELEMENT);
		return $string;
	}
	
	private function nextOfType() {
		$types = func_get_args();
		// skip to next
		$this->read();
		// check if it's one of the types requested and loop until it's one we want
		while($this->nodeType && !(in_array($this->nodeType, $types))) {
			// node isn't of type requested, so keep going
			$this->read();
		}
	}
	
	private function isNodeOfTypeName($type, $name) {
		return $this->nodeType === $type && $this->name === $name;
	}
}

$parser = new plistParser();
$plist = $parser->parseFile(dirname(__FILE__) . "/../Info.plist");
$CFBundleIdentifier = $plist['CFBundleIdentifier'];
$title = $plist['title'];
$CFBundleGetInfoString = $plist['CFBundleGetInfoString'];
$bannerCSSSelector = $plist['bannerCSSSelector'];
$bannerHeight = $plist['bannerHeight'];
$bannerWidth = $plist['bannerWidth'];
$isFromKTScaledImageTypesBannerImage = FALSE;
$viewport = $plist['viewport'];

if (isset($plist['KTScaledImageTypes']))
{
	$KTScaledImageTypes = $plist['KTScaledImageTypes'];
	if (isset($KTScaledImageTypes['bannerImage']))
	{
		$bannerImage = $KTScaledImageTypes['bannerImage'];
		$bannerWidth = $bannerImage['maxWidth'];
	  	$bannerHeight = $bannerImage['maxHeight'];
		$isFromKTScaledImageTypesBannerImage = TRUE;
	}
}

$fontMarkup = '';
$fontInfo = '';
if (isset($plist['import']))
{
	$imports = $plist['import'];
	foreach($imports as $importURL)
	{
		$ieMarkup .= "<link rel='stylesheet' type='text/css' href='$importURL' />\n";
		$fontInfo .= "<p style='font-size:150%;'><b>Font:</b> We are importing <a href='" . htmlspecialchars($importURL) . "'>this</a></p>\n";
	}
}

$ieMarkup = '';
$ieInfo = '';
if (isset($plist['IE']))
{
	$dictForIE = $plist['IE'];
	foreach($dictForIE as $predicate => $file)
	{
		$ieMarkup .= "<!--[if $predicate]><link rel='stylesheet' type='text/css' href='../$file' /><![endif]-->\n";
		$ieInfo .= "<p style='font-size:150%;'><b>Internet Explorer:</b> We are loading <a href='../$file'>$file</a> for <span style='color:red;'>[if $predicate]</span></p>\n";
	}
}


?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
	<head>
		<meta http-equiv="content-type" content="text/html; charset=UTF-8" />
		<title><?php echo htmlspecialchars($CFBundleIdentifier); ?></title>
		<meta name="robots" content="all" />
		<meta name="generator" content="Sandvox Pro 2.0a15 (16751)" />
		<meta name="viewport" content="width=772" />
		<link rel="canonical" href="http://foo.bar/cinderella/mice/blossom.html" />
		<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.3/jquery.min.js"></script>

		<link rel="stylesheet" type="text/css" href="http://designerskit.karelia.com/sandvox.css" /> <!-- This is loaded across ALL designs, no matter what - do not remove or replace -->
		<link rel="stylesheet" type="text/css" href="_Resources/ddsmoothmenu.css" />

<script type="text/javascript" src="_Resources/ddsmoothmenu.js">
/***********************************************
* Smooth Navigational Menu- (c) Dynamic Drive DHTML code library (www.dynamicdrive.com)
* This notice MUST stay intact for legal use
* Visit Dynamic Drive at http://www.dynamicdrive.com/ for full source code
***********************************************/
</script>
<script type="text/javascript">
ddsmoothmenu.arrowimages = {down:['downarrowclass', '_Resources/down.gif', 23], right:['rightarrowclass', '_Resources/right.gif']}
ddsmoothmenu.init({ mainmenuid: 'sitemenu-content',orientation:'h', classname:'ddsmoothmenu',contentsource:'markup'})
</script>
<?php
echo "<!-- IE conditional based on Info.plist -->\n";
echo $ieMarkup;
echo "\n";
echo "<!-- Font import markup based on Info.plist -->\n";
echo $fontMarkup;
echo "\n";
?>
<link rel="stylesheet" type="text/css" href="../main.css" title="YOUR_DESIGN_NAME" />  <!-- This will be replaced by the reference to YOUR NEW STYLE SHEET -->
<link rel="stylesheet" type="text/css" href="../color.css" />  <!-- Optional load of color variation.  Rename any .css file to "color.css" so that this will load. -->
<style type="text/css">
<?php echo htmlspecialchars($bannerCSSSelector); ?> 
{ background-image: url("http://launch.karelia.com/images/design_infoplist_test/BannerTest.jpg?size=<?php echo $bannerWidth; ?>,<?php echo $bannerWidth; ?>&crop=<?php echo $bannerWidth; ?>,<?php echo $bannerHeight; ?>,0,0,northwest"); }
</style>
<!--
Photo credits for this website's design: <<NOT APPLICABLE MARKER>Credits.rtf>
Licensing for this website's design:     <<NOT APPLICABLE MARKER>License.rtf>
-->
	</head>
	<body class="sandvox has-page-title allow-sidebar has-custom-banner no-IR no-navigation" id="foo_bar" >
		<div id="page-container">
			<div id="page">
				<div id="page-top" class="no-logo has-title has-tagline">
					<div id="title">
						<h1 class="title in"><a href="../../"><span class="in">Banner Test: "<?php echo htmlspecialchars($title); ?>"</span></a></h1>
						<p class="tagline"><span class="in">This file must be loaded over a web server, NOT as just a file://</span></p>
					</div><!-- title -->
					<div id="sitemenu-container">
						<div id="sitemenu">
<h2 class="hidden">Site Navigation<a href="#page-content" rel="nofollow">[Skip]</a></h2>
<div id="sitemenu-content">
<ul>
	<li class="i1 o"><a href="../../" title="Home"><span class="in">Home</span></a></li>
	<li class="i2 e"><a href="../../hansel-and-gretel.html" title="Hansel and Gretel"><span class="in">Hansel and Gretel</span></a></li>
	<li class="i3 o"><a href="../../rumpelstiltskin.html" title="Rumpelstiltskin"><span class="in">Rumpelstiltskin</span></a></li>
	<li class="i4 e"><a href="../../little-mermaid.html" title="Little Mermaid"><span class="in">Little Mermaid</span></a></li>
	<li class="i5 o hasSubmenu"><a href="../../snow-white/" title="Snow White"><span class="in">Snow White</span></a>
		<ul>
			<li class="i1 o"><a href="../../snow-white/dopey.html" title="Dopey"><span class="in">Dopey</span></a></li>
			<li class="i2 e"><a href="../../snow-white/grumpy.html" title="Grumpy"><span class="in">Grumpy</span></a></li>
			<li class="i3 o"><a href="../../snow-white/doc.html" title="Doc"><span class="in">Doc</span></a></li>
			<li class="i4 e"><a href="../../snow-white/happy.html" title="Happy"><span class="in">Happy</span></a></li>
			<li class="i5 o"><a href="../../snow-white/bashful-evokes-his-bashful.html" title="Bashful evokes his bashful nature through a classic pose of shyness"><span class="in">Bashful evokes his bashful nature through a classic pose of shyness</span></a></li>
			<li class="i6 e"><a href="../../snow-white/sneezy-frequently-shown.html" title="Sneezy: frequently shown with one finger underneath his nose"><span class="in">Sneezy: frequently shown with one finger underneath his nose</span></a></li>
			<li class="i7 o"><a href="../../snow-white/sleepy-perhaps-the-most.html" title="Sleepy: perhaps the most difficult to differentiate"><span class="in">Sleepy: perhaps the most difficult to differentiate</span></a></li>
			<li class="i8 e last hasSubmenu"><a href="../../snow-white/other-characters/" title="Other Characters"><span class="in">Other Characters</span></a>
				<ul>
					<li class="i1 o"><a href="../../snow-white/other-characters/wicked-queen.html" title="Wicked Queen"><span class="in">Wicked Queen</span></a></li>
					<li class="i2 e last"><a href="../../snow-white/other-characters/father.html" title="Father"><span class="in">Father</span></a></li>
				</ul>
			</li>
		</ul>
	</li>
	<li class="i6 e last hasSubmenu currentParent"><a href="../" title="Cinderella"><span class="in">Cinderella</span></a>
		<ul>
			<li class="i1 o hasSubmenu currentParent"><a href="./" title="Mice"><span class="in">Mice</span></a>
				<ul>
					<li class="i1 o"><a href="gus.html" title="Gus"><span class="in">Gus</span></a></li>
					<li class="i2 e"><a href="jaq.html" title="Jaq"><span class="in">Jaq</span></a></li>
					<li class="i3 o"><a href="suzy.html" title="Suzy"><span class="in">Suzy</span></a></li>
					<li class="i4 e"><a href="perla.html" title="Perla"><span class="in">Perla</span></a></li>
					<li class="i5 o currentPage"><span class="in">Blossom</span></li>
					<li class="i6 e"><a href="luke.html" title="Luke"><span class="in">Luke</span></a></li>
					<li class="i7 o"><a href="mert.html" title="Mert"><span class="in">Mert</span></a></li>
					<li class="i8 e last"><a href="bart.html" title="Bart"><span class="in">Bart</span></a></li>
				</ul>
			</li>
			<li class="i2 e hasSubmenu"><a href="../tremaine-family/" title="Tremaine Family"><span class="in">Tremaine Family</span></a>
				<ul>
					<li class="i1 o"><a href="../tremaine-family/lady-tremaine.html" title="Lady Tremaine"><span class="in">Lady Tremaine</span></a></li>
					<li class="i2 e"><a href="../tremaine-family/anastasia-tremaine.html" title="Anastasia Tremaine"><span class="in">Anastasia Tremaine</span></a></li>
					<li class="i3 o"><a href="../tremaine-family/drizella-tremaine.html" title="Drizella Tremaine"><span class="in">Drizella Tremaine</span></a></li>
					<li class="i4 e last hasSubmenu"><a href="../tremaine-family/other-people-who-are-who/" title="Other people who are who are probably part of the Tremaine Household"><span class="in">Other people who are who are probably part of the Tremaine Household</span></a>
						<ul>
							<li class="i1 o last"><a href="../tremaine-family/other-people-who-are-who/doorman.html" title="Doorman"><span class="in">Doorman</span></a></li>
						</ul>
					</li>
				</ul>
			</li>
			<li class="i3 o last"><a href="../prince-charming.html" title="Prince Charming"><span class="in">Prince Charming</span></a></li>
		</ul>
	</li>
</ul>
</div> <!-- /sitemenu-content -->
</div> <!-- /sitemenu -->
					</div> <!-- sitemenu-container -->
				</div> <!-- page-top -->
				<div class="clear below-page-top"></div>
				<div id="page-content" class="no-navigation">
					<div id="sidebar-container">
	<div id="sidebar">
  		<div id="sidebar-top"></div>
		<div id="sidebar-content">
			<h3 class="hidden">Sidebar<a rel="nofollow" href="#main">[Skip]</a></h3>
<div class="pagelet SVPlugInGraphic untitled i1 o">
    
    <div class="pagelet-body">
        
        <!-- sandvox.BadgeElement --><p style="text-align:center; padding-top:30px; padding-bottom:30px;">
<a class="imageLink" style="background:none; border:none;" href="http://www.sandvox.com/?utm_source=cust_site&amp;utm_medium=banner&amp;utm_content=b1&amp;utm_campaign=pointback&amp;h=vLykBglvTVCUywG4GhFWNtbLBpA%3D" title="Learn about Sandvox - Using your Macintosh, publish your photo album / blog / website on any ISP"><img src="_Resources/sandvox_icon_white.png" alt="Created with Sandvox - Build and publish a web site with your Mac - for individuals, education, and small business" /></a>
</p>
<!-- /sandvox.BadgeElement -->
        
    </div>
</div>
		</div> <!-- sidebar-content -->
		<div id="sidebar-bottom"></div>	
	</div> <!-- sidebar -->
</div> <!-- sidebar-container -->

					<div id="main">
						<div id="main-top"></div>
                            						<div id="main-content">
							<h2 class="title"><span class="in">Test of the banner CSS selector in the info.plist</span></h2>
							

							<div class="article">
								<div class="article-content">
<div class="RichTextElement">
<div><p>This uses the same internal mechanism as Sandvox to replace a banner image, according to the CSS specified in the info.plist string.  The banner selector for the "<?php echo htmlspecialchars($title); ?> " design is:</p>
<pre style="font-size:200%;">
<?php echo htmlspecialchars($bannerCSSSelector); ?>
</pre>
<p>
The banner is cropped to <span style="font-size:200%;"><?php echo htmlspecialchars($bannerWidth); ?> &times; <?php echo htmlspecialchars($bannerHeight); ?></span> pixels.
<?php if ($isFromKTScaledImageTypesBannerImage) echo "(KTScaledImageTypes)"; ?>
</p>
	<?php
   if (!empty($fontInfo)) echo $fontInfo;
   if (!empty($ieInfo)) echo $ieInfo;

	?>

</div>
</div>
</div> <!-- /article-content -->
								<div class="article-info">




								</div> <!-- /article-info -->
							</div> <!-- /article -->
						</div> <!-- main-content -->

						<div id="main-bottom"></div>
					</div> <!-- main -->
				</div> <!-- content -->
				<div class="clear below-content"></div>
				<div id="page-bottom">
					<div id="page-bottom-contents">
						<div><span class="in"><?php echo htmlspecialchars($CFBundleGetInfoString); ?></span></div>
						<div class="hidden"> <a rel="nofollow" href="#title">[Back To Top]</a></div>
					</div>
				</div> <!-- page-bottom -->
			</div> <!-- container -->
			<div id="extraDiv1"><span></span></div><div id="extraDiv2"><span></span></div><div id="extraDiv3"><span></span></div><div id="extraDiv4"><span></span></div><div id="extraDiv5"><span></span></div><div id="extraDiv6"><span></span></div>
		</div> <!-- specific body type -->
		
		
 <!-- special for viewport testing -->
<div style="background:black;">
<div style="margin:auto; background:red; padding:10px 0; color:white; font-weight: bold; width:<?php echo $viewport; ?>px;">This is the iphone viewport width, <?php echo $viewport; ?> pixels.  Make sure that margin is minimal.</div>
</div>


	</body>
</html>
