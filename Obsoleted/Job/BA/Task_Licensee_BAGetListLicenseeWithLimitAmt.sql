USE [bodb_Licensee]
GO
/****** Object:  StoredProcedure [dbo].[Task_Licensee_BAGetListLicenseeWithLimitAmt]    Script Date: 05/17/2013 02:51:57 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_Licensee_BAGetListLicenseeWithLimitAmt]	
AS
/*
Created: 20110916@Elly
Task : Get list of licensee(s) with their limit amount

DB: DB052.bodb_Licensee
Original:
	
--test
Revisions:	
	- 20110922@Henry: Add Dela to the list (50K limit)
	- 20111006@Henry: Add AsiaBet88 and TLC to the list (100K limit)
	- 20111213@Henry: Add Zzun88 to the list
	- 20111219@Henry: Add Bodog to the list
	- 20120323@Henry: Add Mayfair to the list
	- 20120628@Henry: Add Macaubet to the list
	- 20120912@Henry: Add VCAsia to the list
	- 20130218@Daniel: Add ITCBet, LiveBet365 to the list
	- 20130502@Kiwi: Add Aoncash to the list
	- 20130509@Kiwi: Add Avia to the list
	- 20130517@Daniel: Add SunGame to the list
	
Param's Explanation:
*/
BEGIN
SET NOCOUNT ON
	SELECT l.LicenseeID
		,l.LicenseeName
		,CASE WHEN l.LicenseeID =1 THEN 200000 
			WHEN l.LicenseeID=2 THEN 100000
			WHEN l.LicenseeID=4 THEN 100000 
			WHEN l.LicenseeID=6 THEN 100000
			WHEN l.LicenseeID=7 THEN 100000
			WHEN l.LicenseeID=10 THEN 50000
			WHEN l.LicenseeID=14 THEN 50000
			WHEN l.LicenseeID=9 THEN 50000
			WHEN l.LicenseeID=19 THEN 100000
			WHEN l.LicenseeID=21 THEN 100000
			WHEN l.LicenseeID in (24,22,58) THEN 80000
			WHEN l.LicenseeID=25 THEN 100000						
			WHEN l.LicenseeID=8 THEN 80000
		END AS LimitAmt
	FROM dbo.Licensees AS l WITH(NOLOCK)
		INNER JOIN dbo.LicenseeBAConfig AS BA WITH(NOLOCK) ON l.LicenseeID=BA.LicenseeID
			AND BA.EnableBA=1
			AND l.LicenseeID IN (1,2,4,6,7,8,10,14,9,19,21,24,25,22,58) --12Bet,Asiabet88, Alog,TLC, dela, Zzun88, Bodog, Mayfair, Macaubet, ITCBet, LiveBet365, Aoncash, Avia
	
SET NOCOUNT OFF

END

GO
GRANT EXECUTE ON [dbo].[Task_Licensee_BAGetListLicenseeWithLimitAmt] TO [bodbAdminNet] AS [dbo]