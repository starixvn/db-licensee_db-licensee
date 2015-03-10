USE CustDB
GO

CREATE PROCEDURE Dot_CustBAActive_IsBAMember @CustId INT
	, @IsBAMember BIT = 0 OUTPUT
AS  
/*
Created: 20150305@Patrick
Task : Indicate this member is BA member or not
DB: DBTXN/CustDB
Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	SET @IsBAMember = 0
	
	SELECT @IsBAMember = 1
	FROM dbo.Dep_CustBAActive WITH(NOLOCK)
	WHERE CustId = @CustId

END
GO
GRANT EXECUTE ON [dbo].[Dot_CustBAActive_IsBAMember] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Dot_CustBAActive_IsBAMember] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Dot_CustBAActive_IsBAMember] TO [Dot_Member] AS [dbo]
GO
