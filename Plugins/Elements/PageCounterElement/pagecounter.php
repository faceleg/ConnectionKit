<?php

/*
 
DROP TABLE IF EXISTS PageCounts;
CREATE TABLE  `PageCounts` (
	`urlID` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT ,
	`url` VARCHAR(100) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL ,
	`count` BIGINT NOT NULL default '0',
	PRIMARY KEY(urlID)
) ENGINE = innodb CHARACTER SET utf8 COLLATE utf8_unicode_ci;
 
 ALTER TABLE PageCounts ADD INDEX(url);
 

 
 */
 
header ("Content-Type: text/javascript");

$url = rawurldecode($_GET["page"]);

$dbServer = "mysql.karelia.com";
$dbName = "pagecounter";
$dbUsername = "username";
$dbPassword = "password";
$dbTable = "PageCounts";

$con = mysql_connect($dbServer, $dbUsername, $dbPassword);
$count = 0;

if ($con)
{
	if (mysql_select_db($dbName, $con))
	{
		$res = mysql_query("SELECT * FROM $dbTable WHERE url = '$url';", $con);
		if ($res)
		{
			if (mysql_num_rows($res) == 0)
			{
				$res = mysql_query("INSERT INTO $dbTable (url, count) VALUES ('$url', 1);", $con);
				$count = "1";
			}
			else
			{
				$row = mysql_fetch_row($res);
				$count = $row[2] + 1;
				$res = mysql_query("UPDATE $dbTable SET count=$count WHERE url = '$url';", $con);
			}
		}
	}
}

@mysql_close($con);
print "var svxPageCount = \"".$count."\";";



