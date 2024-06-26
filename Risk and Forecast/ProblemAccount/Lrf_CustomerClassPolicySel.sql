/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Lrf_CustomerClassPolicySel
	@site VARCHAR(50),
	@IsTest BIT = 0
AS
	/*
		Created: 20200909@Johnson
		Task: Problem Account - Get customer class policy 
		DB: DBCUST/CUSTDB
		
		Revisions:
			- 20200909@Johnson: initial sp [redmine:#141157]
			- 20201103@Winfred: Get RepeatedBets  and SpreadGroup on customer class [redmine:#144706]
			- 20201125@Winfred: Get MinBet  and Platform on customer class [redmine:#146000]
			- 20201223@Winfred: Get AgentBetInterval and Currency on customer class [redmine:#146969]
			- 20221025@Johnson: Add DisableParlay [redmine: #178994]
			- 20231212@Luke: LAP - Switch to new structure of CTS [Redmine: #197111]
			- 20240625@Winfred: LAP - Get data from Spread Management [redmine:#207016]
	*/
BEGIN
	SET NOCOUNT ON

	-- Get Class for Site
	;WITH T as (
	SELECT r.CustomerClass, r.IsLive AS LiveIndicator, r.SportType, r.RuleID, r.RuleTitle, pm.PolicyTitle, r.BetDelay, r.NextBetInterval, r.MaxBet, r.MaxPerMatch, sm.Site, r.RepeatedBets, sm.Platform, r.MinBet, sm.Currency AS CurrencyID, r.AgentBetInterval, r.DisableParlay
	FROM			CustomerClassRule r					WITH (NOLOCK)
		INNER JOIN CustomerClassPolicyRule pr			WITH (NOLOCK) ON r.RuleID = pr.RuleID
		INNER JOIN CustomerClassSiteManagement sm		WITH (NOLOCK) ON pr.PolicyID = sm.PolicyID
		INNER JOIN CustomerClassPolicyManagement pm		WITH (NOLOCK) ON pm.PolicyID = pr.PolicyID
		INNER JOIN Site s								WITH (NOLOCK) ON s.site = sm.Site
	WHERE s.isLicensee = 1
		AND r.Enable = 1
		AND pm.IsTest <= @IsTest
		AND sm.Site = @site
	), 
	T1 AS
	(
		SELECT CustomerClass,Liveindicator,SportType,RuleID,RuleTitle,PolicyTitle,BetDelay,NextBetInterval,MaxBet,MaxPerMatch,Site, RepeatedBets, Platform, MinBet, CurrencyID, AgentBetInterval, DisableParlay
		FROM T 
		UNION ALL
		SELECT r.CustomerClass, r.IsLive AS LiveIndicator, r.SportType, r.RuleID, r.RuleTitle, pm.PolicyTitle, r.BetDelay, r.NextBetInterval, r.MaxBet, r.MaxPerMatch, sm.Site, r.RepeatedBets, sm.Platform, r.MinBet, sm.Currency AS CurrencyID, r.AgentBetInterval, r.DisableParlay
		FROM			CustomerClassRule r					WITH (NOLOCK)
			INNER JOIN CustomerClassPolicyRule pr			WITH (NOLOCK) ON r.RuleID = pr.RuleID
			INNER JOIN CustomerClassSiteManagement sm		WITH (NOLOCK) ON pr.PolicyID = sm.PolicyID
			INNER JOIN CustomerClassPolicyManagement pm		WITH (NOLOCK) ON pm.PolicyID = pr.PolicyID
		WHERE Enable = 1
			AND pm.IsTest <= @IsTest
			AND sm.Site IN ('All', 'AllDeposit')
			AND NOT EXISTS (SELECT 1
							FROM T
							WHERE t.customerClass = r.CustomerClass
								AND t.SportType = r.SportType
								AND t.Liveindicator = r.IsLive
							)
	)

	SELECT  CustomerClass,Liveindicator,SportType,RuleTitle,PolicyTitle,LeagueGroupID,(BetDelay-1)*100 AS BetDelay,NextBetInterval,MaxBet,MaxPerMatch,Site, RepeatedBets, Platform, MinBet, CurrencyID, AgentBetInterval, DisableParlay
	FROM T1
		CROSS APPLY (
			SELECT STRING_AGG(LeagueGroupID,',') WITHIN GROUP (ORDER BY LeagueGroupID) AS LeagueGroupID
			FROM CustomerClassRuleLeagueGroup rlg WITH (NOLOCK)
			WHERE T1.RuleID = rlg.RuleID
		) lg
	ORDER BY CustomerClass,SportType,LeagueGroupID,Liveindicator
END