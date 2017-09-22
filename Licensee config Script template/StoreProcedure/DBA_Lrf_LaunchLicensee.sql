/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
  
ALTER PROCEDURE [dbo].[DBA_Lrf_LaunchLicensee]  
(  
	@LicenseeName VARCHAR(10),  
	@AffectedDate SMALLDATETIME =''  
)  
AS  
/*  
	Created: 20150126@Jim  
	Task : re-structure create new licensee flow  
	DB: DBLIC.bodb_licensee  
	Original :  
   
	Revisions:  
		- 20170912@Harper: Clear code [RedmineID: #82673] 
   
	Param's Explanation:    
		- @AffectedDate: Launch Date of Licensee
*/  
  
BEGIN   
	 DECLARE @LicenseeId INT  
      
	 SELECT @LicenseeId  = LicenseeId   
	 FROM dbo.Licensees WITH (NOLOCK)   
	 WHERE LicenseeName = @LicenseeName  
   
	 UPDATE dbo.Licensees   
	 SET AffectedDate = @AffectedDate  
	 WHERE LicenseeId = @LicenseeId      
END
GO