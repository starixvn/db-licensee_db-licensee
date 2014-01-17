/**
 * Created by	: Florent
 * Date			: 20140113
 * Task			: Set active for report Winloss By League for Sungame
 * DB			: DBLIC.bodb_Licensee,
 * Revisions	:

 * Parameters:
 *	•
 *	•
 *  
 */
USE bodb_licensee
GO 

SET IDENTITY_INSERT dbo.LicenseeFunctions ON
 
DECLARE @FuntionID INT, @LicenseeID INT,@DisplayOrder INT  
SELECT  @FuntionID=59,@LicenseeID=8,@DisplayOrder=33
BEGIN 
BEGIN TRANSACTION
--add Functions 

IF NOT EXISTS(SELECT TOP 1 1 FROM functions WHERE FunctionId=@FuntionID)
BEGIN
	INSERT INTO functions (FunctionId,NAME,Description,ParentId,Url,IsMenu,IsActive,DisplayOrder,IsNew)
	VALUES (@funtionID,N'WinLoss By League','',3,N'Report/WinLossByLeague',1,1,@DisplayOrder,0)
END

--add LicenseeFunctions

IF NOT  EXISTS (SELECT TOP 1 1 FROM LicenseeFunctions  WHERE licenseeid =@LicenseeID AND FunctionId=@funtionID) 
	INSERT INTO LicenseeFunctions (LicenseeId,FunctionId) VALUES (@licenseeID,@FuntionID)
	
--add LicenseeUserFunctions

DELETE LicenseeUserFunctions WHERE licenseeid=@licenseeID AND FunctionId=@funtionID

INSERT INTO LicenseeUserFunctions (UserId, FunctionId, LicenseeId) 
SELECT distinct UserId,@funtionID,a.LicenseeId from LicenseeUserFunctions a WHERE licenseeid=@licenseeID

COMMIT
END 

SET IDENTITY_INSERT dbo.LicenseeFunctions OFF