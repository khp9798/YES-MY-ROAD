package com.b201.api.domain;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.locationtech.jts.geom.Point;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.Builder;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 지도상의 캡처 포인트 엔티티 (위치 정보를 POINT 타입으로 저장)
 */
@Entity
@Getter
@NoArgsConstructor
@EqualsAndHashCode(onlyExplicitlyIncluded = true)
@Table(name = "capture_point")
public class CapturePoint {

	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	@EqualsAndHashCode.Include
	@Column(name = "capture_point_id", nullable = false, unique = true)
	private Integer capturePointId;

	@Column(name = "public_id", length = 36, nullable = false, unique = true)
	private String publicId;

	@Column(name = "capture_timestamp", nullable = false)
	private LocalDateTime captureTimestamp;

	@JdbcTypeCode(SqlTypes.GEOMETRY)
	@Column(name = "location", nullable = false)
	private Point location;

	@Column(name = "accuracy_meters")
	private Double accuracyMeters;

	@Column(name = "image_url", nullable = false)
	private String imageUrl;

	@Column(name = "risk", length = 10)
	private Double risk;

	// CascadeType.ALL 로 변경: Persist, Merge, Remove 모두 전파
	@OneToMany(
		mappedBy = "capturePoint",
		cascade = CascadeType.ALL,
		orphanRemoval = true,
		fetch = FetchType.LAZY
	)
	private List<CaptureDamage> captureDamages = new ArrayList<>();

	@Column(name = "street_address")
	private String streetAddress;

	@Setter
	@ManyToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "region_id")
	private Region region;

	@PrePersist
	public void prePersist() {
		if (publicId == null) {
			publicId = UUID.randomUUID().toString();
		}
	}

	// 양방향 관계를 위한 편의 메서드
	public void addDamage(CaptureDamage damage) {
		damage.setCapturePoint(this);
		this.captureDamages.add(damage);
	}

	@Builder(toBuilder = true)
	public CapturePoint(
		LocalDateTime captureTimestamp,
		Point location,
		Double accuracyMeters,
		String imageUrl,
		Double risk,
		String streetAddress
	) {
		this.captureTimestamp = captureTimestamp;
		this.location = location;
		this.accuracyMeters = accuracyMeters;
		this.imageUrl = imageUrl;
		this.risk = risk;
		this.streetAddress = streetAddress;
	}

}
