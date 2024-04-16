/*<info serverAlias="DBACC-bodb02"></info>*/
/*
	Created: 20240410@Eddie
	DB: DBACC-bodb02
	Task: Grant permission to new account 'ow_12bet' [Redmine: #202118]
*/

USE bodb02
GO

GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_DailySummaryCurrency_Agent] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[Dot_Dep_Rpt_DailySummaryTopV2_Agent] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[Dot_Dep_Rpt_DailySummaryTopV2_Agent_LC] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_MemberSummary_Agent] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_MemberSummary_Agent_V2] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_DailySummaryMember] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_DailySummaryMember_Agent] TO [ow_12bet]
GO
-- more grant  
GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_DailySummaryCurrency_Agent_xtest] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_DailySummaryCurrency_Agent_TST] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[Dot_Dep_Rpt_DailySummaryTopV2_Agent_xtest] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[Dot_Dep_Rpt_DailySummaryTopV2_Agent_TST] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[Dot_Dep_Rpt_DailySummaryTopV2_Agent_LC_xtest] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[Dot_Dep_Rpt_DailySummaryTopV2_Agent_LC_UAT1] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_MemberSummary_Agent_Test] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_MemberSummary_Agent_TST] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_MemberSummary_Agent_UAT1] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_MemberSummary_Agent_xtest] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_MemberSummary_Agent_V2_test] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_MemberSummary_Agent_V2_UAT1] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_MemberSummary_Agent_V2_xtest] TO [ow_12bet]
GO
GRANT EXECUTE ON [dbo].[DOT_Dep_Rpt_DailySummaryMember_Agent_TST] TO [ow_12bet]
GO

