USE bodb_licensee
GO

/*
	Created: 20170712@Harper
	Description: #79838

	Haydock (Bodog) - Change licensee type from OW to Zelianta	
*/

DECLARE @ZeResellerID INT, @OWResellerID INT
SELECT @ZeResellerID = ResellerID FROM dbo.Resellers WITH (NOLOCK) WHERE ResellerName = 'Zelianta'
SELECT @OWResellerID = ResellerID FROM dbo.Resellers WITH (NOLOCK) WHERE ResellerName = 'ONEworks'

SELECT @ZeResellerID, @OWResellerID

DECLARE @LicenseeId INT
SELECT @LicenseeId = LicenseeID FROM Licensees WITH (NOLOCK) WHERE LicenseeName = 'Bodog'

INSERT INTO dbo.LicenseeReseller
        ( ResellerID, LicenseeID )
VALUES  ( @ZeResellerID, -- ResellerID - int
          @LicenseeId -- LicenseeID - int          
        )

INSERT INTO dbo.OA_GroupLicensees
        ( GroupID, ResellerID, LicenseeID )
SELECT Groupid
		, @ZeResellerID
		, @LicenseeID
FROM dbo.OA_GroupLicensees WITH (NOLOCK)
WHERE licenseeid = 9
	AND resellerid = 2

INSERT INTO dbo.OA_UserLicensees
        ( UserID, ResellerID, LicenseeID )
SELECT Userid
		, @ZeResellerID
		, @LicenseeID
FROM dbo.OA_UserLicensees WITH (NOLOCK)
WHERE licenseeid = 9
		AND resellerid = 2
		
-- UPDATE FUNCTION OF RE-SELLER
 	
INSERT INTO dbo.OA_FunctionLicensees (FunctionID, ResellerID, LicenseeID)  
 SELECT DISTINCT oaf.FunctionID  
     ,@ZeResellerID  
     ,@LicenseeId  
 FROM dbo.OA_Functions oaf WITH (NOLOCK) 
 WHERE oaf.FunctionId   IN (  
          3  -- REPORTS  
         ,23 -- Number Game   
         ,27 -- Licensee Win Loss  
         ,28 -- Settled Match Count  
         ,31 -- Match Win Loss  
         ,32 -- Win Loss By Products  
         ,33 -- Win Loss By Bet Type  
         ,36 -- Cancelled Bets  
         ,37 -- Daily Bet List  
         ,38 -- Live Report  
         ,39 -- Turnover  
         ,52 -- CUSTOMER REPORTS  
         ,53 -- Mobile Win Loss  
         ,41 -- Results  
         ,42 -- Balance  
         ,29 -- Customer Win Loss  
         ,30 -- Customer Pending Funds  
         ,40 -- Customer Balance  
         ,51 -- Customer Turnover  
         ,64 -- Active Customer Summary  
         )
	AND oaf.FunctionId NOT IN (SELECT FunctionId
								FROM dbo.OA_FunctionLicensees WITH (NOLOCK)
								WHERE LicenseeID   = @LicenseeId	
									AND ResellerID = @ZeResellerID
								)