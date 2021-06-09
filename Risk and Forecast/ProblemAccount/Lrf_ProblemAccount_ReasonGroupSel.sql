/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Lrf_ProblemAccount_ReasonGroupSel
	@Langkey	VARCHAR(20) = 'en-US'
AS
	/*
		Created: 20200410@Eden
		Task: Problem Account - Get Reason Group 
		DB: DBACC/bodb02
		
		Revisions:
			- 20200410@Eden: initial sp [redmine:#131929]
			- 20210607@Johnson: 
		Paramter's Explanations:		
	*/
BEGIN
	SET NOCOUNT ON
	
	SELECT CustomerClass,
		CategoryID as ReasonGroupID, 
		CASE WHEN @Langkey = 'zh-CN' THEN CategoryNameCS ELSE CategoryName END AS ReasonGroup 
	FROM CategoryConfig WITH(NOLOCK)
	WHERE OfferDeposit = 1
END
GO	
