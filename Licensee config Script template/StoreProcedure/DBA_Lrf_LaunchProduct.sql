/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
  
ALTER PROCEDURE [dbo].[DBA_Lrf_LaunchProduct]  
(  
	@LicenseeName VARCHAR(10),  
	@ProductCode   VARCHAR(100)='',  
	@EffectiveDate SMALLDATETIME =''  
)  
AS  
/*  
	Created: 20150126@Jim  
	Task : re-structure create new licensee flow  
	DB: DBLIC.bodb_licensee  
	Original :  
   
	Revisions:  
   
	Param's Explanation:  
   
*/  
  
BEGIN   
	 DECLARE @LicenseeId	INT  
			,@ProductID		INT  

	 SELECT @LicenseeId  = LicenseeId   
	 FROM dbo.Licensees WITH (NOLOCK)   
	 WHERE LicenseeName = @LicenseeName  
   
	 SELECT @ProductId = ProductId  
	 FROM dbo.Product3rd WITH (NOLOCK)  
	 WHERE ProductPrefix  = @ProductCode  
   
	 UPDATE dbo.LicenseeProduct3rd   
	 SET EffectiveDate = @EffectiveDate  
	 WHERE LicenseeId = @LicenseeID  
		AND ProductId = @ProductID  
END