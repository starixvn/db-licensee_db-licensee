/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[NAP_LM_LicenseeSelSourceAgent]
	@SRecommend INT,
	@UsernameAgent VARCHAR(30) OUTPUT
AS
/*
	Created: 20230605@Winfred
	Task: Get agent source for new function to create agent subsidiary
	DB: DBACC.bodb02
	Revisions:
		- 20230605@Winfred: NAP LM - New function to create agent subsidiary for TM team [redmine:#185123]
		- 20240812@Helios: Scale out DBCUST - Licensee Customer in GlobCustDB [redmine: #207474] 

	Parameter's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @CustidAgent INT

	CREATE TABLE #tblmrecommend  (CustID INT PRIMARY KEY)
		
	INSERT INTO #tblmrecommend(CustID)
	SELECT custid FROM custinfo WITH (NOLOCK) WHERE roleid=3
	and username LIKE '%Acc%' and srecommend=@SRecommend		
	
	SELECT @CustidAgent = (SELECT MIN(custid)   
				FROM dbo.customer WITH(NOLOCK)   
				WHERE Srecommend = @SRecommend 
				AND mrecommend NOT IN (SELECT CustID FROM #tblmrecommend)
				AND RoleId = 2)
	SELECT @UsernameAgent = username FROM customer WITH(NOLOCK) WHERE custid = @CustidAgent

	DROP TABLE #tblmrecommend
END
GO
