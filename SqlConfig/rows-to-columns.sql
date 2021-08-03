select o1.RelativeTimestamp
    ,  o1.ApplicationUri
    ,  o1.NodeId
    ,  DipData              =      (
                                    select       o2.[value] 
                                    from       dbo.OpcNodes as o2 
                                    where       o1.applicationuri = o2.applicationuri 
                                        and o2.SourceTimestamp between o1.RelativeTimestamp and dateadd(millisecond, 999, o1.RelativeTimestamp) 
                                        and o2.DisplayName = 'DipData'
                                )
    ,  SpikeData            =      (
                                    select       o2.[value] 
                                    from       dbo.OpcNodes as o2 
                                    where       o1.applicationuri = o2.applicationuri 
                                        and o2.SourceTimestamp between o1.RelativeTimestamp and dateadd(millisecond, 999, o1.RelativeTimestamp) 
                                        and o2.DisplayName = 'SpikeData'
                                )
    ,  RandomSignedInt32    =      (
                                    select       o2.[value] 
                                    from       dbo.OpcNodes as o2 
                                    where       o1.applicationuri = o2.applicationuri 
                                        and o2.SourceTimestamp between o1.RelativeTimestamp and dateadd(millisecond, 999, o1.RelativeTimestamp) 
                                        and o2.DisplayName = 'RandomSignedInt32'
                                )
from   
    (
        select       
            ApplicationUri
            , NodeId
            , RelativeTimestamp = dateadd(millisecond, -datepart(millisecond, SourceTimestamp), SourceTimestamp)
        from  dbo.OpcNodes
        group by
            ApplicationUri
            , NodeId
            , dateadd(millisecond, -datepart(millisecond, SourceTimestamp), SourceTimestamp) -- group records at the seconds level
    )  as o1;
