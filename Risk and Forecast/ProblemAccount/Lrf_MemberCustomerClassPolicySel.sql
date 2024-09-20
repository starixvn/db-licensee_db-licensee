/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE Lrf_MemberCustomerClassPolicySel
	@Custid  INT,
	@CustomerClass	SMALLINT,
	@site VARCHAR(50),
	@CurrencyID	TINYINT,
	@IsTest BIT = 0
AS
	/*
		Created: 20240911@Winfred
		Task: Show policy of Saba Virtual Sports 
		DB: DBACC-bodb02
		
		Revisions:
			- 20240911@Winfred: LAP - Risk Level - Show policy of Saba Virtual Sports [redmine:#210545]
	*/
BEGIN
	SET NOCOUNT ON

	-- Get Class for Site
	;WITH Scc as (
	SELECT SportType, CustomerClass
	FROM CustomerClassSetting s WITH (NOLOCK)
	WHERE s.custid = @Custid
	), T as (
	SELECT r.CustomerClass, r.CustomerClassDetail, r.IsLive AS LiveIndicator, r.SportType, r.RuleID, r.RuleTitle, pm.PolicyTitle, r.BetDelay, r.NextBetInterval, r.MaxBet, r.MaxPerMatch, sm.Site, r.RepeatedBets, sm.Platform, r.MinBet, sm.Currency AS CurrencyID, r.AgentBetInterval, r.DisableParlay,
		CASE r.SportType WHEN 1 THEN 10  WHEN 9901 THEN 20 WHEN 2 THEN 30 WHEN 9902 THEN 40 WHEN 43 THEN 50 WHEN 99 THEN 60 ELSE 70 END AS fOrder
	FROM CustomerClassRule r							WITH (NOLOCK)
		INNER JOIN CustomerClassPolicyRule pr			WITH (NOLOCK) ON r.RuleID = pr.RuleID
		INNER JOIN CustomerClassSiteManagement sm		WITH (NOLOCK) ON pr.PolicyID = sm.PolicyID
		INNER JOIN CustomerClassPolicyManagement pm		WITH (NOLOCK) ON pm.PolicyID = pr.PolicyID
		INNER JOIN Site s								WITH (NOLOCK) ON s.site = sm.Site
	WHERE s.isLicensee = 1
		AND r.Enable = 1
		AND pm.IsTest <= @IsTest
		AND sm.Site = @site
		AND sm.Currency = @CurrencyID
		AND NOT EXISTS (SELECT 1 FROM Scc WHERE Scc.SportType = r.SportType)
		AND r.CustomerClass = @CustomerClass
	UNION ALL 
	SELECT r.CustomerClass, r.CustomerClassDetail, r.IsLive AS LiveIndicator, r.SportType, r.RuleID, r.RuleTitle, pm.PolicyTitle, r.BetDelay, r.NextBetInterval, r.MaxBet, r.MaxPerMatch, sm.Site, r.RepeatedBets, sm.Platform, r.MinBet, sm.Currency AS CurrencyID, r.AgentBetInterval, r.DisableParlay,
		CASE r.SportType WHEN 1 THEN 10  WHEN 9901 THEN 20 WHEN 2 THEN 30 WHEN 9902 THEN 40 WHEN 43 THEN 50 WHEN 99 THEN 60 ELSE 70 END AS fOrder
	FROM CustomerClassRule r							WITH (NOLOCK)
		INNER JOIN CustomerClassPolicyRule pr			WITH (NOLOCK) ON r.RuleID = pr.RuleID
		INNER JOIN CustomerClassSiteManagement sm		WITH (NOLOCK) ON pr.PolicyID = sm.PolicyID
		INNER JOIN CustomerClassPolicyManagement pm		WITH (NOLOCK) ON pm.PolicyID = pr.PolicyID
		INNER JOIN Site s								WITH (NOLOCK) ON s.site = sm.Site
		INNER JOIN Scc sc								WITH (NOLOCK) ON r.SportType = sc.SportType
	WHERE s.isLicensee = 1
		AND r.Enable = 1
		AND pm.IsTest <= @IsTest
		AND sm.Site = @site
		AND sm.Currency = @CurrencyID
		AND EXISTS (SELECT 1 FROM Scc WHERE Scc.SportType = r.SportType)
		AND r.CustomerClass IN ( @CustomerClass, 0)
		AND ISNUll(r.CustomerClassDetail,0) IN (sc.CustomerClass, 0)
	), 
	T1 AS
	(
		SELECT CustomerClass,CustomerClassDetail,Liveindicator,SportType,RuleID,RuleTitle,PolicyTitle,BetDelay,NextBetInterval,MaxBet,MaxPerMatch,Site, RepeatedBets, Platform, MinBet, CurrencyID, AgentBetInterval, DisableParlay , fOrder
		FROM T 
		UNION ALL
		SELECT r.CustomerClass,r.CustomerClassDetail, r.IsLive AS LiveIndicator, r.SportType, r.RuleID, r.RuleTitle, pm.PolicyTitle, r.BetDelay, r.NextBetInterval, r.MaxBet, r.MaxPerMatch, sm.Site, r.RepeatedBets, sm.Platform, r.MinBet, sm.Currency AS CurrencyID, r.AgentBetInterval, r.DisableParlay, 
			CASE r.SportType WHEN 1 THEN 10  WHEN 9901 THEN 20 WHEN 2 THEN 30 WHEN 9902 THEN 40 WHEN 43 THEN 50 WHEN 99 THEN 60 ELSE 70 END AS fOrder
		FROM CustomerClassRule r							WITH (NOLOCK)
			INNER JOIN CustomerClassPolicyRule pr			WITH (NOLOCK) ON r.RuleID = pr.RuleID
			INNER JOIN CustomerClassSiteManagement sm		WITH (NOLOCK) ON pr.PolicyID = sm.PolicyID
			INNER JOIN CustomerClassPolicyManagement pm		WITH (NOLOCK) ON pm.PolicyID = pr.PolicyID
		WHERE Enable = 1
			AND pm.IsTest <= @IsTest
			AND NOT EXISTS (SELECT 1 FROM Scc WHERE Scc.SportType = r.SportType)
			AND r.CustomerClass = @CustomerClass
			AND (
				(sm.Site IN ('All', 'AllDeposit') AND sm.Currency = @CurrencyID) OR
				(sm.Site = @site AND sm.Currency = 0))
			AND NOT EXISTS (SELECT 1
							FROM T
							WHERE t.customerClass = r.CustomerClass
								AND t.SportType = r.SportType
								AND t.Liveindicator = r.IsLive
							)
		UNION ALL
		SELECT r.CustomerClass,r.CustomerClassDetail, r.IsLive AS LiveIndicator, r.SportType, r.RuleID, r.RuleTitle, pm.PolicyTitle, r.BetDelay, r.NextBetInterval, r.MaxBet, r.MaxPerMatch, sm.Site, r.RepeatedBets, sm.Platform, r.MinBet, sm.Currency AS CurrencyID, r.AgentBetInterval, r.DisableParlay, 
			CASE r.SportType WHEN 1 THEN 10  WHEN 9901 THEN 20 WHEN 2 THEN 30 WHEN 9902 THEN 40 WHEN 43 THEN 50 WHEN 99 THEN 60 ELSE 70 END AS fOrder
		FROM CustomerClassRule r							WITH (NOLOCK)
			INNER JOIN CustomerClassPolicyRule pr			WITH (NOLOCK) ON r.RuleID = pr.RuleID
			INNER JOIN CustomerClassSiteManagement sm		WITH (NOLOCK) ON pr.PolicyID = sm.PolicyID
			INNER JOIN CustomerClassPolicyManagement pm		WITH (NOLOCK) ON pm.PolicyID = pr.PolicyID
			INNER JOIN Scc sc								WITH (NOLOCK) ON r.SportType = sc.SportType
		WHERE Enable = 1
			AND pm.IsTest <= @IsTest
			AND EXISTS (SELECT 1 FROM Scc WHERE Scc.SportType = r.SportType)
			AND (
				(sm.Site IN ('All', 'AllDeposit') AND sm.Currency = @CurrencyID) OR
				(sm.Site = @site AND sm.Currency = 0))
			AND r.CustomerClass IN ( @CustomerClass, 0)
			AND ISNUll(r.CustomerClassDetail,0) IN (sc.CustomerClass, 0)
			AND NOT EXISTS (SELECT 1
							FROM T
							WHERE t.customerClass = r.CustomerClass
								AND t.CustomerClassDetail = r.CustomerClassDetail
								AND t.SportType = r.SportType
								AND t.Liveindicator = r.IsLive
							)
	)

	SELECT  CustomerClass, CustomerClassDetail,Liveindicator,SportType,RuleTitle,PolicyTitle,LeagueGroupID,(BetDelay-1)*100 AS BetDelay,NextBetInterval,MaxBet,MaxPerMatch,Site, RepeatedBets, Platform, MinBet, CurrencyID, AgentBetInterval, DisableParlay, fOrder
	FROM T1
		CROSS APPLY (
			SELECT STRING_AGG(LeagueGroupID,',') WITHIN GROUP (ORDER BY LeagueGroupID) AS LeagueGroupID
			FROM CustomerClassRuleLeagueGroup rlg WITH (NOLOCK)
			WHERE T1.RuleID = rlg.RuleID
		) lg
	ORDER BY fOrder,CustomerClass,SportType,LeagueGroupID,Liveindicator
END