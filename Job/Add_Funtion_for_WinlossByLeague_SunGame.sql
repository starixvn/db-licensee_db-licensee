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
DECLARE @FuntionID INT, @LicenseeID INT,@DisplayOrder INT  
SELECT  @FuntionID=59,@LicenseeID=8,@DisplayOrder=33
BEGIN 
BEGIN TRANSACTION
--add Functions 
INSERT INTO functions VALUES (@funtionID,N'WinLoss By League','',3,N'Report/WinLossByLeague',1,1,@displayOrder,0)
--add LicenseeFunctions
IF NOT  EXISTS (SELECT TOP 1 1 FROM LicenseeFunctions  WHERE licenseeid =@LicenseeID AND FunctionId=@funtionID) 
INSERT INTO LicenseeFunctions (LicenseeId,FunctionId) VALUES (@licenseeID,@FuntionID)
--add LicenseeUserFunctions
INSERT INTO LicenseeUserFunctions (UserId, FunctionId, LicenseeId) 
SELECT distinct UserId,@funtionID,a.LicenseeId from LicenseeUserFunctions a WHERE licenseeid=@licenseeID

COMMIT
END 