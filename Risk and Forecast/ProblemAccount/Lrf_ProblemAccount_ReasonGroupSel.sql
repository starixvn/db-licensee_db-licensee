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
			
		Paramter's Explanations:		
	*/
BEGIN
	SET NOCOUNT ON
	SELECT ReasonGroupID, 
		CASE WHEN @Langkey = 'zh-CN' THEN MIN(ReasonNameCS) ELSE MIN(ReasonName) END AS ReasonGroup 
	FROM ProblemAccountReason WITH(NOLOCK)
	WHERE ReasonGroupID IS NOT NULL
	GROUP BY ReasonGroupID
	ORDER BY ReasonGroupID
END
GO	
