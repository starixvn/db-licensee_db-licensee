/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="wsv_lap" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LogAction_LicSel]
AS
/*
    Created: 20250529@Tacy
    Task: LAP - Select LogAction_Lic
    DB: DBLOG-bodb_CustomerLog
    
    Revisions:
        - 20250529@Tacy: Create SP [RedmineID: #227673]
*/
BEGIN
	SET NOCOUNT ON;

	SELECT la.ActionId, la.ActionName
		, lat.ActionTypeId, lat.ActionTypeName
	FROM LogAction_Lic la WITH (NOLOCK)
	INNER JOIN LogActionType_Lic lat WITH (NOLOCK)
		ON lat.ActionTypeId=la.ActionTypeId
	WHERE lat.ActionTypeId>=10 AND la.ActionId <> 4002
END