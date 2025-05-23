package com.b201.api.domain;

import java.time.LocalDateTime;

import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.Builder;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@EntityListeners(AuditingEntityListener.class)
@NoArgsConstructor
@Getter
@EqualsAndHashCode(onlyExplicitlyIncluded = true)
@Table(name = "capture_damage")
public class CaptureDamage {

	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	@EqualsAndHashCode.Include
	@Column(unique = true, nullable = false, name = "damage_id")
	private Integer damageId;

	@Setter
	@ManyToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "capture_point_id", nullable = false)
	private CapturePoint capturePoint;

	@ManyToOne
	@JoinColumn(name = "category_id", nullable = false)
	private DamageCategory damageCategory;

	@Setter
	@Enumerated(EnumType.STRING)
	@Column(name = "status", nullable = false, length = 20)
	private DamageStatus status;

	@Column(name = "description")
	private String description;

	@Column(name = "created_at", nullable = false, updatable = false)
	private LocalDateTime createdAt;

	@LastModifiedDate
	@Column(name = "updated_at")
	private LocalDateTime updatedAt;

	@PrePersist
	public void prePersist() {
		if (this.status == null) {
			this.status = DamageStatus.REPORTED;
		}
	}

	@Builder
	public CaptureDamage(
		CapturePoint capturePoint,
		DamageCategory damageCategory,
		String description,
		DamageStatus status,  // <- 상태를 명시적으로 받거나
		LocalDateTime createdAt
	) {
		this.capturePoint = capturePoint;
		this.damageCategory = damageCategory;
		this.description = description;
		this.status = status != null ? status : DamageStatus.REPORTED;
		this.createdAt = createdAt;
	}

	@Getter
	public enum DamageStatus {
		REPORTED(0), RECEIVED(1), IN_PROGRESS(2), COMPLETED(3);
		private final int number;

		DamageStatus(int number) {
			this.number = number;
		}

	}

}
