 /*<info serverAlias="DBLIC-bodb_Licensee" executers="wsv_lap" viewers="" isFunction="0"></info>*/ 
 ALTER PROCEDURE [dbo].[Lrf_GroupCommCheckByName]
	@LicenseeID INT,
	@GroupName VARCHAR(100)
AS  
/*  
 * Created: 20120726@Henry
 * Task : Check the existence of Group Name
 * DB: DBLIC-bodb_Licensee
 *  
 * Revisions:     
	- 20240624@Johnson: Restructure Commission [redmine:#179088]
*/  
BEGIN  
SET NOCOUNT ON;  

DECLARE @isAvailable BIT



SELECT @GroupName = ltrim(rtrim(@GroupName))

IF EXISTS (
	SELECT 1 FROM LicenseeGroupDiscount WITH (NOLOCK)
	WHERE 
		LicenseeID = @LicenseeID
		AND GroupName = @GroupName
		AND IsActive = 1
)
BEGIN
	SELECT 0 AS IsAvailable
END
ELSE
BEGIN
	SELECT 1 AS IsAvailable
END

	

END
GO